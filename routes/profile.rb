module Afterburner
  class Website < Sinatra::Application
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

      @permissions = Permission.all
      @permissions = @permissions.sort { |a,b| a.slug <=> b.slug }

      erb :profile
    end

    post '/profile/:github_login' do
      @profile_user = User.find(params[:github_login])
      unless @profile_user
        redirect '/'
      end

      # Do you have permission to update this profile?
      if !@user.has_permission?("permissions_grant") &&
         !@user.has_permission?("users_update") &&
         @profile_user.github_login != @user.github_login
        redirect "/profile/#{params[:github_login]}"
      end

      form do
        field :name, :present => true, :filters => [ :strip ]
        field :email, :present => true, :email => true, :filters => [ :strip, :downcase ]
        field :t_shirt_size, :present => true, :regexp => %r{^(S|M|L|XL|XXL)$}
      end
      if form.failed?
        flash[:error] = "Something when wrong. Check the form and try again."
        redirect "/profile/#{params[:github_login]}"
      end

      @profile_user.name = form[:name]
      @profile_user.email = form[:email]
      @profile_user.t_shirt_size = form[:t_shirt_size]

      if @user.has_permission?("permissions_grant")
        perms = []
        if params[:permissions]
          for perm_slug in params[:permissions] do
            perms << Permission.where(slug: perm_slug).first
          end
        end
        @profile_user.permissions = perms

        if params[:type]
          # TODO: check this for type errors
          @profile_user.type = params[:type]
        end
      end

      # TODO: check for errors
      @profile_user.save

      flash[:message] = "Profile updated."
      redirect "/profile/#{params[:github_login]}"
    end
  end
end
