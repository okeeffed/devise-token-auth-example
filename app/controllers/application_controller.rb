class ApplicationController < ActionController::Base
  skip_forgery_protection
  include DeviseTokenAuth::Concerns::SetUserByToken
end
