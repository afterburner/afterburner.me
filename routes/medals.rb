module Afterburner
  class Website < Sinatra::Application
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
  end
end
