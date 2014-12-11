module Afterburner
  class Website < Sinatra::Application
    get '/admin/applications' do
      require!("applications_view")

      @sessions = Session.all
      @applications = []
      for s in @sessions
        apps = Application.where(session: s)

        if apps && apps.count > 0
          @applications << { :session => s, :applications => apps }
        end
      end

      @applications.sort! { |a,b| b[:session].start <=> a[:session].start }

      erb :admin_applications
    end

    post '/admin/application/:application_id/:action' do
      require!("applications_update")

      application = Application.where(id: params[:application_id]).first

      unless application
        flash[:error] = "Couldn't find that application."
        redirect '/admin/applications'
      end

      unless params[:action] =~ /accepted|rejected/
        flash[:error] = "Invalid action on an application."
        redirect '/admin/applications'
      end

      application.status = params[:action]
      application.save

      # TODO: check for errors here

      flash[:message] = "Application updated."
      redirect '/admin/applications'
    end
  end
end
