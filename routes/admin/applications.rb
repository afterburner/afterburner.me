module Afterburner
  class Website < Sinatra::Application
    get '/admin/applications' do
      require!("applications_view")

      @sessions = Session.all
      @applications = []
      for s in @sessions
        apps = Application.where(session: s)
        if apps
          @applications << { :session => s, :applications => apps }
        end
      end

      @applications.sort! { |a,b| b[:session].start <=> a[:session].start }

      erb :admin_applications
    end

    post '/admin/application/:application_id' do
      require!("applications_update")
    end
  end
end
