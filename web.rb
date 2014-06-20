require 'sinatra'
require 'sinatra_auth_github'

module Afterburner
  class Website < Sinatra::Application
    enable :sessions

    register Sinatra::Auth::Github

    set :github_options, {
      :secret       => ENV['GITHUB_CLIENT_SECRET'],
      :client_id    => ENV['GITHUB_CLIENT_ID'],
      :callback_url => ENV['GITHUB_OAUTH_CALLBACK'],
    }

    get '/' do
      erb :index
    end

    get '/application' do
      erb :application
    end

    get '/application/challenge' do
      authenticate!
    end
  end
end
