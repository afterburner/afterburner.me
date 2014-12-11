module Afterburner
  class Website < Sinatra::Application
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

  end
end
