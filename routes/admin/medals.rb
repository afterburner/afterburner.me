module Afterburner
  class Website < Sinatra::Application
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
  end
end
