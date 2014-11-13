require 'sinatra'
require 'sinatra_auth_github'
require 'uri'
require 'mongoid'
require 'sinatra/formkeeper'
require 'sinatra/flash'

require_relative 'afterburner/model'
require_relative 'afterburner/users'
require_relative 'afterburner/medals'

Mongoid.load!("mongoid.yml")

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
        @user = Afterburner::Users.find(github_user.login)
      else
        @user = nil
      end
    end

    get '/' do
      erb :index, :layout => false
    end

    get '/signup' do
      require!
      erb :signup
    end

    post '/signup' do
      require!

      # Check for a user with this github login.
      u = Afterburner::Users.find(github_user.login)
      if u
        redirect '/profile/' + github_user.login
      end

      form do
        field :name, :present => true
        field :email, :present => true, :email => true
      end
      if form.failed?
        erb :signup
      else
        u = Afterburner::Users.create(github_login: github_user.login,
                                      name: params[:name],
                                      email: params[:email],
                                      t_shirt_size: params[:t_shirt_size],
                                      type: :cadet)

        redirect '/profile/' + github_user.login
      end
    end

    get '/profile/:github_login' do
      @profile_user = Afterburner::Users.find(params[:github_login])
      unless @profile_user
        redirect '/'
      end
      erb :profile
    end

    def current_application
      @repos = github_user.api.repositories

      erb :current
    end

    post '/apply/:session_slug' do
      require!

      # Validate the session they're applying for.
      s = Session.where(slug: params[:session_slug]).first
      time = Time.now
      if s.nil? || time < s.apply_start || time > s.apply_end
        current_application
      end

      # Validate the form input.
      form do
        field :repo, :present => true
        field :project_description, :present => true
      end
      if form.failed?
        current_application
      else
        Application.create(github_login: github_user.login,
                           repo: form[:repo],
                           project_description: form[:project_description],
                           session: s)

        redirect '/apply/thanks'
      end
    end

    get '/auth/logout' do
      logout!
      redirect '/'
    end

    get '/auth/login' do
      authenticate!
      redirect '/'
    end

    get '/apply/thanks' do
      erb :apply_thanks
    end

    get '/medals/decorate' do
      require!("medals_decorate")

      @users = Afterburner::Users.all
      @medals = Afterburner::Medals.all

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

      u = Afterburner::Users.find(params[:github_login])
      m = Afterburner::Medals.find(params[:medal_id])

      if form.failed? || u.nil? || m.nil?
        flash[:error] = 'Something went wrong.'
      else
        u.decorations.create(medal: m, user: u)

        flash[:message] = "\"#{m.name}\" awarded to #{u.name}."
      end

      redirect '/medals/decorate'
    end

    post '/admin/permissions' do
      require!("permissions_create")

      form do
        field :slug, :present => true
        field :name, :present => true
      end
      if form.failed?
        redirect '/admin/permissions'
      else
        Permission.create(:slug => params[:slug],
                          :name => params[:name])
      end
    end

    get '/admin/medals' do
      require!("medals_view")

      @medals = Afterburner::Medals.all.sort { |a,b| a.sort_key <=> b.sort_key }
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

      @users = Afterburner::Users.all
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
        for perm_slug in params[:permissions] do
          perms << Permission.where(slug: perm_slug).first
        end
        u = Afterburner::Users.create(github_login: params[:github_login],
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
      users = Afterburner::Users.all
      @cadet_leaders = []

      # TODO: cache these in memory for a while
      users.each { |u|
        if (u.type != :cadet)
          next
        end

        points = 0
        for d in u.decorations
          points += d.medal.points
        end
        @cadet_leaders << { points: points, user: u }
      }

      @cadet_leaders.sort! { |a,b|
        b[:points] <=> a[:points]
      }
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
