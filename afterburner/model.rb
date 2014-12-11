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
  end

  class Permission
    include Mongoid::Document
    field :slug, type: String
    field :name, type: String
  end

  class Session
    include Mongoid::Document
    field :slug, type: String
    field :name, type: String
    field :start, type: Time
    field :end, type: Time
    field :apply_start, type: Time
    field :apply_end, type: Time
    has_one :challenge
    has_many :applications
  end

  class Medal
    include Mongoid::Document
    include Mongoid::Timestamps
    field :name, type: String
    field :image, type: String
    field :image_disabled, type: String
    field :points, type: Integer
    field :sort_key, type: String
    field :description, type: String
    field :secret, type: Boolean
    has_many :decorations
  end

  class Decoration
    include Mongoid::Document
    include Mongoid::Timestamps
    belongs_to :user
    belongs_to :medal
  end

  class Challenge
    include Mongoid::Document
    include Mongoid::Timestamps
    field :slug, type: String
    field :name, type: String
    belongs_to :session
  end

  class Application
    include Mongoid::Document
    include Mongoid::Timestamps
    field :repo, type: String
    field :project_description, type: String
    field :status, type: Symbol
    belongs_to :user
    belongs_to :session
  end
end
