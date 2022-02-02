require 'sinatra'
require 'sinatra/reloader'
require 'sqlite3'
require_relative 'playtime.rb'



get '/' do
    slim(:index)
end