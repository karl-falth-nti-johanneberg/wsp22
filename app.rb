require 'sinatra'
require 'sinatra/reloader'
require_relative 'playtime.rb'

database = SQLite3::Database.new "db/playtime.db"
database.results_as_hash = true
pt = Playtime.new
# exempel: pt.getdb("cheesemax", "", database)
get '/' do
    @user_list_with_data = database.execute("select user_name, date_time, playtime from users inner join playtime_records on users.user_id = playtime_records.user_id order by playtime_records.user_id asc")
    slim(:index)
end
get '/update/:username' do
    if database.execute("select * from users where user_name=?", params[:username]).first == nil
        "user isn't registered to the database."
    else
        pt.getdb(params[:username], "", database)
        redirect '/'
    end
end