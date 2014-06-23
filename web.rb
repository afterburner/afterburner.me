require 'sinatra'
require 'sinatra_auth_github'
require 'uri'
require 'mongoid'

Mongoid.load!("mongoid.yml")

module Afterburner
  class Session
    include Mongoid::Document
    field :name, type: String
  end

  class Challenge
    include Mongoid::Document
    field :name, type: String
  end

  class Submission
    include Mongoid::Document
    field :github_login, type: String
    embeds_one :session
    embeds_one :challenge
  end

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

    get '/apply' do
      erb :apply
    end

    get '/apply/2014-Q3' do
      authenticate!

      @current_session = Session.where(name: "2014-Q3").first

#      prev = Submission.where(github_login: github_user.login,
#                              session: s).first

      @current_challenge = Challenge.where(name: "MovieSuggestions").first

      @repos = github_user.api.repositories

      erb :current
    end

    get '/auth/logout' do
      logout!
      redirect '/apply'
    end
  end
end
