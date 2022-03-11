require 'sinatra'
require 'sinatra/reloader'
require 'sqlite3'
require_relative 'playtime.rb'
# require_relative 'database'

database = SQLite3::Database.new "db/playtime.db"
database.results_as_hash = true
pt = Playtime.new
# exempel: pt.getdb("cheesemax", "", database)
get '/' do
    @user_list_with_data = database.execute("select user_name, date_time, playtime from users inner join playtime_records on users.user_id = playtime_records.user_id order by playtime_records.id asc")
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
get '/combine' do
    @user_list_with_data = database.execute("select user_name, date_time, playtime from users inner join playtime_records on users.user_id = playtime_records.user_id order by playtime_records.id asc")
    return pt.combinename(@user_list_with_data).to_s
end
get '/extrapolate' do
    extrapolated_user_data = {}
    @user_list_with_data = database.execute("select user_name, date_time, playtime from users inner join playtime_records on users.user_id = playtime_records.user_id order by playtime_records.id asc")
    pt.combinename(@user_list_with_data).each do |user_name, data|
        pt.graphdata(user_name, data)
        extrapolated_user_data[user_name] = pt.extrapolate(data)
    end
    extrapolated_user_data.to_s
end