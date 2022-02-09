require 'sinatra'
require 'sinatra/reloader'
require_relative 'playtime.rb'

database = SQLite3::Database.new "db/playtime.db"
database.results_as_hash = true
pt = Playtime.new
# exempel: pt.getdb("cheesemax", "", database)
get '/' do
    user_list_with_data = database.execute("select user_name, playtime from users inner join playtime_records on users.user_id = playtime_records.user_id order by playtime_records.id desc")
    p user_list_with_data
    slim(:index)
end