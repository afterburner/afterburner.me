module Afterburner
  class Website < Sinatra::Application
    get '/apply' do
      authenticate!

      erb :apply
    end

    post '/apply/:session_slug' do
      authenticate!

      # Validate the session they're applying for.
      s = Session.where(slug: params[:session_slug]).first
      time = Time.now
      if s.nil? || time < s.apply_start || time > s.apply_end
        flash[:error] = "Invalid session. Something's really wrong. Contact application@afterburner.me"
        redirect '/apply'
      end

      # Validate the form input.
      form do
        field :repo, :present => true
        field :project_description, :present => true
        field :name, :present => true, :filters => [ :strip ]
        field :email, :present => true, :email => true, :filters => [ :strip, :downcase ]
        field :t_shirt_size, :present => true, :regexp => %r{^(S|M|L|XL|XXL)$}
      end

      if form.failed?
        p form
        flash.now[:error] = "Something when wrong. Check the form and try again."
        output = erb :apply
        fill_in_form(output)
      else
        if @user == nil
          @user = User.create(github_login: github_user.login,
                              name: form[:name],
                              email: form[:email],
                              t_shirt_size: form[:t_shirt_size],
                              type: :cadet)
        end
        Application.create(user: @user,
                           repo: form[:repo],
                           project_description: form[:project_description],
                           status: :pending,
                           session: s)

        redirect '/apply/thanks'
      end
    end

    get '/apply/thanks' do
      erb :apply_thanks
    end
  end
end
