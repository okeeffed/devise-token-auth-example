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

## Part 2: Adding in Omniauth

Added these gems:

```rb
gem 'omniauth-github'
gem 'omniauth-rails_csrf_protection'
```

Follow [my blog](https://blog.dennisokeeffe.com/blog/2022-03-08-part-5-oauth-with-github-and-omniauth).
