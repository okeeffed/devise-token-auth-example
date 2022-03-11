# README

## Steps

Update Gemfile:

```rb
gem 'devise'
gem 'omniauth'
gem 'devise_token_auth', '>= 1.2.0', git: "https://github.com/lynndylanhurley/devise_token_auth"
```

```s
# Generate and setup files
$ bin/rails g devise:install
$ bin/rails g devise_token_auth:install User auth

# Create and migrate DBs
$ bin/rails db:create db:migrate
```

Update `app/controllers/application_controller.rb` to skip forgery so I can use Postman:

```rb
class ApplicationController < ActionController::Base
  skip_forgery_protection
  include DeviseTokenAuth::Concerns::SetUserByToken
end
```

From the response need to grab three of the headers will be used while testing sign out.

1. `client`
2. `uid`
3. `access-token`

To test, create a new controller:

```s
# Generate controller
$ bin/rails g controller api/v1/home
```

Update `app/controllers/api/v1/home_controller.rb`:

```rb
class Api::V1::HomeController < ApplicationController
  before_action :authenticate_user!

  def index
    render json: { message: 'Welcome to the API' }
  end
end
```

Update the `routes.rb` file:

```rb
Rails.application.routes.draw do
  mount_devise_token_auth_for 'User', at: 'auth'
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"
  namespace :api do
    namespace :v1 do
      resources :home, only: [:index]
    end
  end
end
```

## Testing

Sign in and save response headers.

Next, set the headers.

After using the token, in a request, a new one will be given back and you need to track it between requests.

After usage of a token, it will expire.

## Things to note

- Default [`token_lifespan`](https://devise-token-auth.gitbook.io/devise-token-auth/config/initialization) is 2 weeks.

## Part 2: Devise with Doorkeeper

## Doorkeeper

```s
# Add gem
$ bundler add doorkeeper

# Ruby
$ bin/rails g doorkeeper:install
$ bin/rails g doorkeeper:migration
```

My migration file looks like this:

```rb
# frozen_string_literal: true

class CreateDoorkeeperTables < ActiveRecord::Migration[7.0]
  def change
    create_table :oauth_access_tokens do |t|
      t.integer  :resource_owner_id
      t.integer  :application_id

      # If you use a custom token generator you may need to change this column
      # from string to text, so that it accepts tokens larger than 255
      # characters. More info on custom token generators in:
      # https://github.com/doorkeeper-gem/doorkeeper/tree/v3.0.0.rc1#custom-access-token-generator
      #
      # t.text :token, null: false
      t.string :token, null: false

      t.string   :refresh_token
      t.integer  :expires_in
      t.datetime :revoked_at
      t.datetime :created_at, null: false
      t.string   :scopes

      # The authorization server MAY issue a new refresh token, in which case
      # *the client MUST discard the old refresh token* and replace it with the
      # new refresh token. The authorization server MAY revoke the old
      # refresh token after issuing a new refresh token to the client.
      # @see https://datatracker.ietf.org/doc/html/rfc6749#section-6
      #
      # Doorkeeper implementation: if there is a `previous_refresh_token` column,
      # refresh tokens will be revoked after a related access token is used.
      # If there is no `previous_refresh_token` column, previous tokens are
      # revoked as soon as a new access token is created.
      #
      # Comment out this line if you want refresh tokens to be instantly
      # revoked after use.
      # t.string   :previous_refresh_token, null: false, default: ''
    end

    add_index :oauth_access_tokens, :token, unique: true
    add_index :oauth_access_tokens, :resource_owner
    add_index :oauth_access_tokens, :refresh_token, unique: true

    # Uncomment below to ensure a valid reference to the resource owner's table
    add_foreign_key :oauth_access_tokens, :users, column: :resource_owner_id
  end
end
```

### Doorkeeper initializer

Doorkeeper initializer `config/initializers/doorkeeper.rb`.

```rb
# frozen_string_literal: true

Doorkeeper.configure do
skip_client_authentication_for_password_grant true

  # Change the ORM that doorkeeper will use (requires ORM extensions installed).
  # Check the list of supported ORMs here: https://github.com/doorkeeper-gem/doorkeeper#orms
  orm :active_record

  # This block will be called to check whether the resource owner is authenticated or not.
  resource_owner_authenticator do
    current_user || warden.authenticate!(scope: :user)
  end

  resource_owner_from_credentials do |_routes|
    User.authenticate(params[:email], params[:password])
  end

	# Issue access tokens with refresh token (disabled by default), you may also
  # pass a block which accepts `context` to customize when to give a refresh
  # token or not. Similar to +custom_access_token_expires_in+, `context` has
  # the following properties:
  #
  # `client` - the OAuth client application (see Doorkeeper::OAuth::Client)
  # `grant_type` - the grant type of the request (see Doorkeeper::OAuth)
  # `scopes` - the requested scopes (see Doorkeeper::OAuth::Scopes)
  #
  use_refresh_token

  # Define access token scopes for your provider
  # For more information go to
  # https://doorkeeper.gitbook.io/guides/ruby-on-rails/scopes
  #
  default_scopes  :read
  optional_scopes :write

  enforce_configured_scopes

  # Specify what grant flows are enabled in array of Strings. The valid
  # strings and the flows they enable are:
  #
  # "authorization_code" => Authorization Code Grant Flow
  # "implicit"           => Implicit Grant Flow
  # "password"           => Resource Owner Password Credentials Grant Flow
  # "client_credentials" => Client Credentials Grant Flow
  #
  # If not specified, Doorkeeper enables authorization_code and
  # client_credentials.
  #
  # implicit and password grant flows have risks that you should understand
  # before enabling:
  #   https://datatracker.ietf.org/doc/html/rfc6819#section-4.4.2
  #   https://datatracker.ietf.org/doc/html/rfc6819#section-4.4.3
  #
  # grant_flows %w[authorization_code client_credentials]
  grant_flows %w[password]


  # Under some circumstances you might want to have applications auto-approved,
  # so that the user skips the authorization step.
  # For example if dealing with a trusted application.
  #
  # skip_authorization do |resource_owner, client|
  #   client.superapp? or resource_owner.admin?
  # end
  skip_authorization do
    true
  end
end
```

## Update User model

```rb
class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher

  has_many :access_grants,
           class_name: 'Doorkeeper::AccessGrant',
           foreign_key: :resource_owner_id,
           dependent: :delete_all # or :destroy if you need callbacks

  has_many :access_tokens,
           class_name: 'Doorkeeper::AccessToken',
           foreign_key: :resource_owner_id,
           dependent: :delete_all # or :destroy if you need callbacks

	# Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  include DeviseTokenAuth::Concerns::User

  class << self
    def authenticate(email, password)
      user = User.find_for_authentication(email: email)
      user.try(:valid_password?, password) ? user : nil
    end
  end
end
```

## Update routes

Add this to the routes.

```rb
use_doorkeeper do
	skip_controllers :authorizations, :applications,
										:authorized_applications
end
```

## Testing our the route

```s
# Get token
$ curl -X POST -d "grant_type=password&email=hello@example.com&password=password" localhost:3000/oauth/token
# Get response

# This won't work
$ curl -v http://localhost:3000/api/v2/home

# This will
$ curl -v localhost:3000/api/items?access_token=OurAccessTokenReturnedByAPI
```
