module Afterburner
  class Medals

    def self.find(id)
      d.where(id: id).first
    end

    def self.all
      Medal.all
    end

    def self.all_public
      all_m = Medal.where(secret: false).documents
      return all_m.sort { |a,b| a.sort_key < b.sort_key }
    end

    # returns [ { :medal => Medal, :count => Integer } ]
    def self.awarded_to(user)
      awarded = {}
      for d in user.decorations
        n = d.medal.id
        if awarded[n].nil?
          awarded[n] = {}
          awarded[n][:medal] = d.medal
          awarded[n][:count] = 1
        else
          awarded[n][:count] = awarded[n][:count] + 1
        end
      end
      for m in self.all_public
        if awarded[m.id].nil?
          awarded[m.id] = {}
          awarded[m.id][:medal] = m
          awarded[m.id][:count] = 0
        end
      end
      return awarded.values.sort { |a,b| a.sort_key < b.sort_key }
    end

  end
end
