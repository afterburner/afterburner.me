require 'sinatra'
require 'sinatra_auth_github'
require 'uri'
require 'mongoid'
require 'sinatra/formkeeper'

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
    field :repo, type: String
    field :project_description, type: String
    field :t_shirt_size, type: String
    embeds_one :session
    embeds_one :challenge
  end

  class Website < Sinatra::Application
    enable :sessions

    register Sinatra::Auth::Github
    register Sinatra::FormKeeper

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

    def current_application
      @repos = github_user.api.repositories

      erb :current
    end

    post '/apply/2014-Q3' do
      authenticate!

      form do
        field :repo, :present => true
        field :project_description, :present => true
        field :t_shirt_size, :present => true, :regexp => %r{S|M|L|XL|XXL}
      end
      if form.failed?
        current_application
      else
        s = Session.where(name: "2014-Q3").first
        c = Challenge.where(name: "MovieSuggestions").first
        Submission.create(github_login: github_user.login,
                          repo: form[:repo],
                          project_description: form[:project_description],
                          t_shirt_size: form[:t_shirt_size],
                          challenge: c,
                          session: s)

        redirect '/apply/thanks'
      end
    end

    get '/apply/2014-Q3' do
      authenticate!

      current_application
    end

    get '/auth/logout' do
      logout!
      redirect '/apply'
    end

    get '/apply/thanks' do
      erb :apply_thanks
    end
  end
end
