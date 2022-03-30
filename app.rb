require 'sinatra'
require 'sinatra/reloader'
require 'sqlite3'
require_relative 'playtime.rb'

database = SQLite3::Database.new "db/playtime.db"
database.results_as_hash = true
pt = Playtime.new
# exempel: pt.getdb("cheesemax", "", database)
get '/' do
    slim(:index)
end
get '/users/' do
    @user_list_with_data = database.execute("select user_name, date_time, playtime from users inner join playtime_records on users.user_id = playtime_records.user_id order by playtime_records.id asc")
    slim(:"users/index")
end
get '/users/new' do
    slim(:"users/new")
end
post '/users' do
    new_user = pt.get(params[:user])
    user_name, user_id = new_user[1], new_user[2]
    db.execute("insert into users (osu_id, user_name) values ?,?", user_id, user_name)
    redirect('/users/' + user_name)
end
get '/users/:username' do
    @user = database.execute("select osu_id, user_name from users where user_name = ?", params[:username]).first
    if @user == nil
        return "user isn't registered to the database."
    end
    return @user["user_name"]
    @user["extrapolated_data"] = pt.combinename(database)[@user["user_name"]]
    @user["graph_image_path"] = pt.graphdata(@user["user_name"], @user["extrapolated_data"])
    slim(:"users/show")
end
get '/users/:username/update' do
    if database.execute("select * from users where user_name=?", params[:username]).first == nil
        "user isn't registered to the database."
    else
        pt.getdb(params[:username], "", database)
        redirect '/users/'
    end
end
get '/extrapolate' do
    extrapolated_user_data = {}
    pt.combinename(database).each do |user_name, data|
        pt.graphdata(user_name, data)
        extrapolated_user_data[user_name] = pt.extrapolate(data)
    end
    return extrapolated_user_data.to_s
end