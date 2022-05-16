require 'sinatra'
require 'sinatra/reloader'
require 'sqlite3'
require 'bcrypt'
require_relative 'playtime.rb'
require_relative 'model.rb'

enable :sessions
include Model
pt = Playtime.new
# exempel: pt.getdb("cheesemax", "", database)



before do
    @logged_in_user = {}
    before_every_route(session)
end

get '/' do
    slim(:index)
end

get '/login' do
    slim(:login)
end

post '/login' do
    username, password = params[:username], params[:password]
    result = get_user(username)
    if result["password_digest"] == nil
        return "User isn't registered."
    end
    if bcrypt(result["password_digest"]) == password
        session[:logged_in_user_id] = result["user_id"]
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
    @user_list_with_data = pt.combinename(open_db())
    slim(:"users/index")
end

get '/users/new' do
    slim(:"users/new")
end

before '/users/delete' do
    if @logged_in_user[:role] != 1
        redirect('/')
    end
end

get '/users/delete' do
    @user_list = user_list()
    slim(:"users/delete")
end

post '/users/delete' do
    to_delete = params.keys
    delete_users(to_delete)
    redirect('/users/delete')
end

post '/users' do
    username, password, password_confirm = params[:username], params[:password], params[:password_confirm]

    new_user = pt.get(username, "")
    osu_id = new_user[2]

    error = register_user(username, password, password_confirm, osu_id)

    if error.class == String
        return error
    end

    redirect('/users/' + username + '/update')
end


get '/users/:username/friend' do
    return logged_in?() if logged_in?() != nil
    error = friend(params[:username])
    if error.class == String
        return error
    end
    redirect('/users/')
end

get '/users/:username/unfriend' do
    return logged_in?() if logged_in?() != nil
    slim(:unfriend, locals:{friender_name:params[:username]})
end

post '/users/:username/unfriend' do
    return logged_in?() if logged_in?() != nil
    error = friend(params[:username])
    if error.class == String
        return error
    end
    redirect('/users/')
end

get '/users/:username' do
    @user = get_user(params[:username])
    if @user == nil
        return "user isn't registered to the database."
    end
    result = pt.combinename(open_db())
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
    update_user(params, pt)
end