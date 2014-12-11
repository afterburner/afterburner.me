module Afterburner
  class Website < Sinatra::Application
    get '/admin/permissions' do
      require!("permissions_view")

      @permissions = Permission.all
      @permissions = @permissions.sort { |a,b| a.slug <=> b.slug }

      erb :admin_permissions
    end

    post '/admin/permission' do
      require!("permissions_create")

      form do
        filters :strip
        field :slug, :present => true, :regexp => %r{^[A-Za-z0-9_]+$}
        field :name, :present => true
      end
      if form.failed?
        flash.now[:error] = "Something went wrong creating this permission."

        @permissions = Permission.all
        @permissions = @permissions.sort { |a,b| a.slug <=> b.slug }
        output = erb :admin_permissions
        fill_in_form(output)
      else
        Permission.create(:slug => form[:slug],
                          :name => form[:name])

        flash[:message] = "Permission \"#{form[:name]}\" created."
        redirect '/admin/permissions'
      end
    end
  end
end
