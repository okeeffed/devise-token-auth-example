class Api::V2::HomeController < ApplicationController
  before_action :doorkeeper_authorize!

  def index
    render json: { message: 'Welcome to the Public DoorKeeper API' }
  end
end
