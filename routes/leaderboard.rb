module Afterburner
  class Website < Sinatra::Application
    get '/leaderboard' do
      users = User.all
      @cadet_leaders = []
      @mentor_leaders = []

      # TODO: cache these in memory for a while
      users.each { |u|
        points = 0
        for d in u.decorations
          points += d.medal.points
        end
        if (u.type == :cadet)
          @cadet_leaders << { points: points, user: u }
        else
          @mentor_leaders << { points: points, user: u }
        end
      }

      @cadet_leaders.sort! { |a,b| b[:points] <=> a[:points] }
      @mentor_leaders.sort! { |a,b| b[:points] <=> a[:points] }
      erb :leaderboard
    end
  end
end
