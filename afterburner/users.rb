module Afterburner
  class Users

    def self.create(params)
      User.create(github_login: params[:github_login],
                  name: params[:name],
                  email: params[:email],
                  t_shirt_size: params[:t_shirt_size],
                  type: params[:type],
                  permissions: params[:permissions])
    end

    def self.find(github_login)
      User.where(github_login: github_login).first
    end

    def self.all
      User.all
    end

  end
end
