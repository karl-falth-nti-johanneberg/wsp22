require 'sinatra'
require 'sinatra/reloader'
require 'sqlite3'
require 'bcrypt'
require_relative 'playtime.rb'
require_relative 'model.rb'

enable :sessions
include Model
pt = Playtime.new

before do
    @logged_in_user = {}
    if defined?(session[:logged_in_user_id]) && session[:logged_in_user_id] != nil
        before_every_route(session[:logged_in_user_id])
    else
        @logged_in_user[:id], session[:logged_in_user_id] = nil, nil
    end
end

# Displays landing page.
#
get '/' do
    slim(:index)
end

# Displays login page.
#
get '/login' do
    slim(:login)
end

# Handles logins and displays appropriate error message or redirects to '/'. Also implements a cooldown feature if a user tries to log in too many times with the wrong credentials.
#
# @param [String] username, The username of the account which someone is trying to log into.
# @param [String] password, The password which the user is trying to log in with.
# @param [Hash] result, User account credentials to be compared with the ones given from the user.
# @param [Object] session[:log], Time object used to facilitate the cooldown functionality.
# @param [Integer] session[:logged_in_user_id], The user id of the currently logged in user.
#
# @see Model#get_user
# @see Model#log
post '/login' do
    if session[:log] != nil && Time.now - session[:log] <= 5
        return "You are on cooldown, stop trying to log in so fast!"
    end
    username, password = params[:username], params[:password]
    result = get_user(username)
    if result["password_digest"] == nil
        session[:log] = log()
        return "User isn't registered."
    end
    if bcrypt(result["password_digest"]) == password
        session[:logged_in_user_id] = result["user_id"]
        redirect('/')
    else
        session[:log] = log()
        return "Wrong password."
    end
end

# Handles logouts and redirects to '/'.
#
# @param [Integer] session[:logged_in_user_id], The user id of the currently logged in user.
# @param [Hash] @logged_in_user, Information about the currently logged in user including: friends, followers, and role.
get '/logout' do
    session[:logged_in_user_id], @logged_in_user = nil, nil
    redirect('/')
end

# Displays list of users in the database.
#
# @param [Hash] @user_list_with_data, List containing logged data corresponding to the right user.
#
# @see Model#open_db
# @see Playtime#combinename
get '/users' do
    # @user_list_with_data = database.execute("select user_name, date_time, playtime from users inner join playtime_records on users.user_id = playtime_records.user_id order by playtime_records.id asc")
    @user_list_with_data = pt.combinename(open_db())
    slim(:"users/index")
end

# Displays form for registering users to the database.
#
get '/users/new' do
    slim(:"users/new")
end

before '/users/delete' do
    if @logged_in_user[:role] != 1
        redirect('/')
    end
end

# Displays form for removing users from the database. Requires admin authority.
#
# @param [Hash] @user_list, List containing all the user information available in the database.
#
# @see Model#user_list
get '/users/delete' do
    @user_list = user_list()
    slim(:"users/delete")
end

# Handles the deletion of users from the database.
#
# @param [Array] to_delete, list of users to be deleted.
#
# @see Model#delete_users
post '/users/delete' do
    to_delete = params.keys
    delete_users(to_delete)
    redirect('/users/delete')
end

# Handles registering users to the database and redirects to the newly registered user's update page.
#
# @param [Object] session[:log], Time object used to facilitate the cooldown functionality.
# @param [String] username, The username of the user who will be registered to the database.
# @param [String] password, The password the user wants to register to the database.
# @param [String] password, Confirmation of the password the user wants to register to the database.
# @param [Array] new_user, Information sourced from the osu! game api containing information about the osu account with the same name as the given username.
# @param [Integer] osu_id, The account id of the osu! profile.
# @param [String] error, Variable used to store and display error messages returned by methods in Model.
#
# @see Playtime#get
# @see Model#register_user
# @see Model#log
post '/users' do
    if session[:log] != nil && Time.now - session[:log] <= 10
        return "You are on cooldown, stop trying to register people so fast!"
    end
    username, password, password_confirm = params[:username], params[:password], params[:password_confirm]

    new_user = pt.get(username, "")
    osu_id = new_user[2]

    if params[:register] == nil
        register_account = false
    else
        register_account = true
    end

    error = register_user(username, password, password_confirm, osu_id, register_account)
    
    session[:log] = log()
    if error.class == String
        return error
    end
    
    redirect('/users/' + username + '/update')
end

# Handles adding friends and redirects to '/users*
#
# @param [String] error, Variable used to store and display error messages returned by methods in Model.
#
# @see Model#logged_in
# @see Model#friend
get '/users/:username/friend' do
    return logged_in() if logged_in() != nil
    error = friend(params[:username])
    if error.class == String
        return error
    end
    redirect('/users')
end

# Shows form to comfirm unfriending a user.
#
get '/users/:username/unfriend' do
    return logged_in() if logged_in() != nil
    slim(:unfriend, locals:{friender_name:params[:username]})
end

# Handles unfriending a user, shows error messages, and redirects to '/users'
#
# @param [Object] session[:log], Time object used to facilitate the cooldown functionality.
# @param [String] error, Variable used to store and display error messages returned by methods in Model.
#
# @see Model#log
post '/users/:username/unfriend' do
    if session[:log] != nil && Time.now - session[:log] <= 1
        return "You are on cooldown, stop trying to unfriend people so fast!"
    end
    return logged_in() if logged_in() != nil
    error = friend(params[:username])

    session[:log] = log()

    if error.class == String
        return error
    end
    redirect('/users')
end

# Displays a user's profile page.
#
# @param [String] params[:username], The username whose page is being requested.
# @param [Hash] @user, Contains all the information about the user.
# @param [Hash] result, Contains all the playtime information in the database.
# @param [Hash] @friends, Contains all the friends of the user, along with their data.
#
# @see Model#get_user
# @see Playtime#combinename
# @see Model#open_db
# @see Playtime#extrapolate
# @see Playtime#graphdata
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

# Handles updating the user and redirects to the user's profile page.
#
# @param [Object] session[:log], Time object used to facilitate the cooldown functionality.
# @param [String] error, Variable used to store and display error messages returned by methods in Model.
#
# @see Model#update_user
get '/users/:username/update' do
    if session[:log] != nil && Time.now - session[:log] <= 0.5
        return "You are on cooldown, stop trying to update profiles so fast!"
    end

    username = params[:username]

    error = update_user(username, pt)

    session[:log] = log()

    if error.class == String
        return error
    end
    redirect '/users/' + params[:username]
end