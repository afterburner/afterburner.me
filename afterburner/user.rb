module Afterburner
  class User
    include Mongoid::Document
    include Mongoid::Timestamps
    field :github_login, type: String
    field :name, type: String
    field :email, type: String
    field :type, type: Symbol
    field :t_shirt_size, type: String
    has_many :applications
    has_and_belongs_to_many :permissions, inverse_of: nil
    has_many :decorations

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
