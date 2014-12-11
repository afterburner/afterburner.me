require 'sinatra'
require 'sinatra_auth_github'
require 'uri'
require 'mongoid'
require 'sinatra/formkeeper'
require 'sinatra/flash'
require 'github_api'
require 'dalli'
require 'memcachier'

require_relative 'afterburner/model'
require_relative 'afterburner/user'
require_relative 'afterburner/medal'
require_relative 'routes/admin/permissions'
require_relative 'routes/admin/users'
require_relative 'routes/admin/medals'
require_relative 'routes/apply'
require_relative 'routes/medals'
require_relative 'routes/leaderboard'
require_relative 'routes/profile'

Mongoid.load!("mongoid.yml")

set :cache, Dalli::Client.new

module Afterburner
  class Website < Sinatra::Application
    enable :sessions

    register Sinatra::Auth::Github
    register Sinatra::FormKeeper

    set :github_options, {
      :secret       => ENV['GITHUB_CLIENT_SECRET'],
      :client_id    => ENV['GITHUB_CLIENT_ID'],
      :callback_url => ENV['GITHUB_OAUTH_CALLBACK'],
    }


    before do
      if github_user && github_user.login
        @user = User.find(github_user.login)
      else
        @user = nil
      end
    end

    get '/' do
      erb :index, :layout => false
    end

    get '/auth/logout' do
      logout!
      redirect '/'
    end

    get '/auth/login' do
      authenticate!
      redirect '/'
    end

    get '/how-to-apply' do
      erb :how_to_apply
    end

    get '/tips' do
      erb :tips
    end

    get '/contribute' do
      erb :contribute
    end

    def require!(*args)
      authenticate!

      unless @user
        redirect '/'
      end

      for a in args do
        unless @user.permissions.where(slug: a).exists?
          redirect '/'
        end
      end
    end

  end
end
