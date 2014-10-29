require 'sinatra'
require 'sinatra_auth_github'
require 'uri'
require 'mongoid'
require 'sinatra/formkeeper'

Mongoid.load!("mongoid.yml")

module Afterburner
  class Permission
    include Mongoid::Document
    field :slug, type: String
    field :name, type: String
  end

  class User
    include Mongoid::Document
    include Mongoid::Timestamps
    field :github_login, type: String
    field :name, type: String
    field :email, type: String
    field :type, type: Symbol
    field :t_shirt_size, type: String
    has_many :applications
    has_and_belongs_to_many :permissions, inverse_of: nil
    has_many :decorations
  end

  class Session
    include Mongoid::Document
    field :slug, type: String
    field :name, type: String
    field :start, type: Time
    field :end, type: Time
    field :apply_start, type: Time
    field :apply_end, type: Time
    has_one :challenge
    has_many :applications
  end

  class Medal
    include Mongoid::Document
    include Mongoid::Timestamps
    field :name, type: String
    field :image, type: String
    field :image_disabled, type: String
    field :points, type: Integer
    field :sort_key, type: String
    field :description, type: String
    field :secret, type: Boolean
    has_many :decorations
  end

  class Decoration
    include Mongoid::Document
    include Mongoid::Timestamps
    belongs_to :user
    belongs_to :medal
  end

  class Challenge
    include Mongoid::Document
    include Mongoid::Timestamps
    field :slug, type: String
    field :name, type: String
    belongs_to :session
  end

  class Application
    include Mongoid::Document
    include Mongoid::Timestamps
    field :github_login, type: String
    field :repo, type: String
    field :project_description, type: String
    belongs_to :user
    belongs_to :session
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

    get '/signup' do
      authenticate!
      erb :signup
    end

    post '/signup' do
      authenticate!

      # Check for a user with this github login.
      u = User.where(github_login: github_user.login).first
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
        u = User.create(github_login: github_user.login,
                        name: params[:name],
                        email: params[:email],
                        t_shirt_size: params[:t_shirt_size],
                        type: :cadet)

        redirect '/profile/' + github_user.login
      end
    end

    get '/profile/:github_login' do
      authenticate!

      @user = User.where(github_login: params[:github_login]).first
      erb :profile
    end

    def current_application
      @repos = github_user.api.repositories

      erb :current
    end

    post '/apply/:session_slug' do
      authenticate!

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

    get '/medals/award/:github_login/:medal_id' do
      authenticate!

      @user = User.where(github_login: github_user.login).first
      unless @user.permissions.where(slug: "award").exists?
        redirect '/'
      end

      m = Medal.where(id: params[:medal_id]).first
      u = User.where(github_login: params[:github_login]).first

      # TODO: error check
      u.decorations.create(medal: m,
                           user: u)

      redirect '/profile/' + params[:github_login]
    end

    get '/admin/users'
      authenticate!

      @user = User.where(github_login: github_user.login).first
      unless @user.permissions.where(slug: "users_view").exists?
        redirect '/'
      end

      @users = User.all
      @permissions = Permission.all
      erb :admin_users
    end

    post '/admin/users'
      authenticate!

      @user = User.where(github_login: github_user.login).first
      unless @user.permissions.where(slug: "users_create").exists?
        redirect '/'
      end

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
        u = User.create(github_login: params[:github_login]
                        name: params[:name],
                        email: params[:email],
                        t_shirt_size: params[:t_shirt_size],
                        type: params[:type],
                        permissions: params[:permissions])

        redirect '/admin/users'
      end
    end

    def public_medals
      all_m = Medal.where(secret: false).documents
      return all_m.sort { |a,b| a.sort_key < b.sort_key }
    end

    # returns [ { :medal => Medal, :count => Integer } ]
    def awarded_medals
      awarded = {}
      for d in @user.decorations
        n = d.medal.id
        if awarded[n].nil?
          awarded[n] = {}
          awarded[n][:medal] = d.medal
          awarded[n][:count] = 1
        else
          awarded[n][:count] = awarded[n][:count] + 1
        end
      end
      for m in public_medals
        if awarded[m.id].nil?
          awarded[m.id] = {}
          awarded[m.id][:medal] = m
          awarded[m.id][:count] = 0
        end
      end
      return awarded.values.sort { |a,b| a.sort_key < b.sort_key }
    end
  end
end
