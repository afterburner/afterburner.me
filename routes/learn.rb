module Afterburner
  class Website < Sinatra::Application
    get '/learn/tips' do
      erb :learn_tips
    end

    get '/learn/reading-list' do
      erb :learn_reading_list
    end
  end
end
