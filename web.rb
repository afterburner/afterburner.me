require 'sinatra'
require 'sinatra_auth_github'
require 'uri'
require 'mongoid'
require 'sinatra/formkeeper'

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

    get '/' do
      erb :index
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

    get '/apply/thanks' do
      erb :apply_thanks
    end

    get '/medals/decorate' do
      require!("medals_decorate")

      @users = Afterburner::Users.all
      @medals = Afterburner::Medals.all

      erb :decorate
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

    post '/medals/decorate/:github_login/:medal_id' do
      require!("medals_decorate")

      m = Afterburner::Medals.find(params[:medal_id])
      u = Afterburner::Users.find(params[:github_login])

      # TODO: error check
      u.decorations.create(medal: m,
                           user: u)

      redirect '/profile/' + params[:github_login]
    end

    get '/admin/users' do
      require!("users_view")

      @users = Afterburner::Users.all
      @permissions = Permission.all
      erb :admin_users
    end

    post '/admin/users' do
      require!("users_create")

      form do
        field :name, :present => true
        field :github_login, :present => true
        field :email, :present => true
        field :t_shirt_size, :present => true
        field :type, :present => true
      end
      if form.failed?
        redirect '/admin/users'
      else
        u = Afterburner::Users.create(github_login: params[:github_login],
                                      name: params[:name],
                                      email: params[:email],
                                      t_shirt_size: params[:t_shirt_size],
                                      type: params[:type],
                                      permissions: params[:permissions])

        redirect '/admin/users'
      end
    end

    def require!(*args)
      authenticate!

      @user = Afterburner::Users.find(github_user.login)
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
