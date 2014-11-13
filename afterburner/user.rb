module Afterburner
  class User
    def self.find(github_login)
      self.where(github_login: github_login).first
    end

    def has_permission?(*perms)
      b = false
      for p in perms
        b |= self.permissions.where(slug: p).exists?
      end
      return b
    end

    def points
      points = 0
      for d in self.decorations
        points += d.medal.points
      end
      return points
    end
  end
end
