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

    get '/profile/:github_login' do
      @profile_user = User.find(params[:github_login])
      unless @profile_user
        redirect '/'
      end
      key = @profile_user.github_login + ":github"
      @profile_user_github ||= settings.cache.fetch(key) do
        github = Github.new(client_id: ENV['GITHUB_CLIENT_ID'],
                            client_secret: ENV['GITHUB_CLIENT_SECRET'])
        u = github.users.get(user: @profile_user.github_login).to_hash
        settings.cache.set(key, u, 60*60*3)
        u
      end

      erb :profile
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

    get '/leaderboard' do
      users = User.all
      @cadet_leaders = []
      @mentor_leaders = []

      # TODO: cache these in memory for a while
      users.each { |u|
        points = 0
        for d in u.decorations
          points += d.medal.points
        end
        if (u.type == :cadet)
          @cadet_leaders << { points: points, user: u }
        else
          @mentor_leaders << { points: points, user: u }
        end
      }

      @cadet_leaders.sort! { |a,b| b[:points] <=> a[:points] }
      @mentor_leaders.sort! { |a,b| b[:points] <=> a[:points] }
      erb :leaderboard
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
