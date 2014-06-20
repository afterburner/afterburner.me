require 'sinatra'

get '/' do
  erb :index
end

get '/application' do
  erb :application
end
