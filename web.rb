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
require_relative 'routes/apply'

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

    get '/medals/decorate' do
      require!("medals_decorate")

      @users = User.all
      @medals = Medal.all

      erb :decorate
    end

    post '/medals/decorate' do
      require!("medals_decorate")

      form do
        field :github_login, :present => true
        field :medal_id, :present => true
      end
      if form.failed?
        flash[:error] = 'Something went wrong.'
      end

      u = User.find(params[:github_login])
      m = Medal.find(params[:medal_id])

      if form.failed? || u.nil? || m.nil?
        flash[:error] = 'Something went wrong.'
      else
        u.decorations.create(medal: m, user: u)

        flash[:message] = "\"#{m.name}\" awarded to #{u.name}."
      end

      redirect '/medals/decorate'
    end

    get '/admin/medals' do
      require!("medals_view")

      @medals = Medal.all.sort { |a,b| a.sort_key <=> b.sort_key }
      erb :admin_medals
    end

    post '/admin/medal' do
      require!("medals_create")

      form do
        field :name, :present => true
        field :image, :present => true
        field :image_disabled, :present => true
        field :points, :present => true, :uint => true
        field :sort_key, :present => true
        field :description, :present => true
        field :secret, :default => "off"
      end
      if form.failed?
        flash[:error] = "Something when wrong. Check the form and try again."
        redirect '/admin/medals'
      else
        m = Medal.create(name: params[:name],
                         image: params[:image],
                         image_disabled: params[:image_disabled],
                         points: params[:points],
                         sort_key: params[:sort_key],
                         description: params[:description],
                         secret: params[:secret] == "on")

        # TODO: check for errors here

        flash[:message] = "Medal \"#{m.name}\" successfully created."
        redirect '/admin/medals'
      end
    end

    get '/admin/users' do
      require!("users_view")

      @users = User.all
      @permissions = Permission.all
      erb :admin_users
    end

    post '/admin/user' do
      require!("users_create")

      form do
        field :name, :present => true
        field :github_login, :present => true
        field :email, :present => true, :email => true
        field :t_shirt_size, :present => true
        field :type, :present => true
      end
      if form.failed?
        flash[:error] = "Something when wrong. Check the form and try again."
        redirect '/admin/users'
      else
        perms = []
        if params[:permissions]
          for perm_slug in params[:permissions] do
            perms << Permission.where(slug: perm_slug).first
          end
        end
        u = User.create(github_login: params[:github_login],
                        name: params[:name],
                        email: params[:email],
                        t_shirt_size: params[:t_shirt_size],
                        type: params[:type],
                        permissions: perms)

        # TODO: check for errors here

        flash[:message] = "User #{u.github_login}/#{u.name} successfully created."
        redirect '/admin/users'
      end
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
