require 'sinatra'
require 'sinatra/reloader'
require 'sqlite3'
require 'bcrypt'
require_relative 'playtime.rb'

database = SQLite3::Database.new "db/playtime.db"
database.results_as_hash = true
enable :sessions
pt = Playtime.new
# exempel: pt.getdb("cheesemax", "", database)



before do
    @logged_in_user = {}
    if defined?(session[:logged_in_user_id]) && session[:logged_in_user_id] != nil
        @logged_in_user[:id] = session[:logged_in_user_id]
        @logged_in_user[:name] = database.execute("select user_name from users where user_id = ?", @logged_in_user[:id]).first["user_name"]
        database.results_as_hash = false
        @logged_in_user[:friends] = database.execute("select user_name from users inner join friends on friended_id = user_id where friender_id = ?", @logged_in_user[:id])
        @logged_in_user[:followers] = database.execute("select user_name from users inner join friends on friender_id = user_id where friended_id = ?", @logged_in_user[:id])
        database.results_as_hash = true
    else
        @logged_in_user[:id], session[:logged_in_user_id] = nil, nil
    end
end

get '/' do
    slim(:index)
end

get '/login' do
    slim(:login)
end

post '/login' do
    username, password = params[:username], params[:password]
    result = database.execute("select user_id, password_digest from users where user_name = ?", username).first
    user_id, password_digest = result["user_id"], result["password_digest"]
    if password_digest == nil
        return "User isn't registered."
    end
    password_digest = BCrypt::Password.new(password_digest)
    if password_digest == password
        session[:logged_in_user_id] = user_id
        redirect('/')
    else
        return "Wrong password."
    end
end

get '/logout' do
    session[:logged_in_user_id], @logged_in_user = nil, nil
    redirect('/')
end

get '/users/' do
    # @user_list_with_data = database.execute("select user_name, date_time, playtime from users inner join playtime_records on users.user_id = playtime_records.user_id order by playtime_records.id asc")
    @user_list_with_data = pt.combinename(database)
    slim(:"users/index")
end

get '/users/new' do
    slim(:"users/new")
end

post '/users' do
    username, password, password_confirm = params[:username], params[:password], params[:password_confirm]

    new_user = pt.get(username, "")
    osu_id = new_user[2]

    result = database.execute("select user_id, password_digest from users where user_name = ?", username).first

    if params[:register] == nil
        if result != nil
            return "User #{username} is already being tracked."
        end
        database.execute("insert into users (osu_id, user_name) values (?,?)", osu_id, username)
    else
        if result["password_digest"] != nil
            return "User #{username} is already registered."
        end
        if password != password_confirm
            return "Password wasn't confirmed properly."
        end
        password_digest = BCrypt::Password.create(password)
        if result["user_id"] != nil
            database.execute("update users set password_digest = ? where user_id = ?", password_digest, result["user_id"])
        else
            database.execute("insert into users (osu_id, user_name, password_digest) values (?,?,?)", osu_id, username, password_digest)
        end
    end
    redirect('/users/' + username + '/update')
end

get '/users/:username/friend' do
    if @logged_in_user[:id] == nil
        return "You can't access this page without logging in."
    end
    friender_id = @logged_in_user[:id]
    friended_id = database.execute("select user_id from users where user_name = ?", params[:username]).first["user_id"]
    result = database.execute("select * from friends where friender_id = ? and friended_id = ?", friender_id, friended_id).first
    if result == nil
        database.execute("insert into friends (friender_id, friended_id) values (?, ?)", friender_id, friended_id)
    end
    redirect('/users/')
end

get '/users/:username/unfriend' do
    if @logged_in_user[:id] == nil
        return "You can't access this page without logging in."
    end
    slim(:unfriend, locals:{friender_name:params[:username]})
end

post '/users/:username/unfriend' do
    friender_id = @logged_in_user[:id]
    friended_id = database.execute("select user_id from users where user_name = ?", params[:username]).first["user_id"]
    result = database.execute("select friender_id, friended_id from friends where friender_id = ? and friended_id = ?", friender_id, friended_id).first
    if result["friender_id"] == friender_id && result["friended_id"] == friended_id
        database.execute("delete from friends where friender_id = ? and friended_id = ?", friender_id, friended_id)
    end
    redirect('/users/')
end

get '/users/:username' do
    @user = database.execute("select osu_id, user_name from users where user_name = ?", params[:username]).first
    if @user == nil
        return "user isn't registered to the database."
    end
    result = pt.combinename(database)
    @user["data"] = result[@user["user_name"]]
    @friends = {}
    if @logged_in_user[:friends] != nil
        @logged_in_user[:friends].each do |friend|
            friend = friend.first
            @friends[friend] = result[friend]
        end
    end
    @user["extrapolated_data"] = pt.extrapolate(@user["data"])
    @user["graph_image_path"] = pt.graphdata(@user["user_name"], @user["data"])
    slim(:"users/show")
end

get '/users/:username/update' do
    if database.execute("select * from users where user_name=?", params[:username]).first == nil
        "user isn't registered to the database."
    else
        pt.getdb(params[:username], "", database)
        redirect '/users/' + params[:username]
    end
end