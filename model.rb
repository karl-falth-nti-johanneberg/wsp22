# Handles connections to the website's database and also references other methods from playtime.rb
#
module Model
    # Opens a connection to the database.
    #
    # @return [Object] database object.
    def open_db()
        database = SQLite3::Database.new "db/playtime.db"
        database.results_as_hash = true
        return database
    end

    # Gathers information about the current user, which is used on the pages. This is called on each route.
    #
    # @param [Hash] session, contains persisting information unique for each user of the page.
    #
    # @see Model#open_db
    #
    # @return [NilClass]
    def before_every_route(session)
        database = open_db()
        if defined?(session[:logged_in_user_id]) && session[:logged_in_user_id] != nil
            @logged_in_user[:id] = session[:logged_in_user_id]
            result = database.execute("select user_name, role from users where user_id = ?", @logged_in_user[:id]).first
            @logged_in_user[:name] = result["user_name"]
            @logged_in_user[:role] = result["role"]
            database.results_as_hash = false
            @logged_in_user[:friends] = database.execute("select user_name from users inner join friends on friended_id = user_id where friender_id = ?", @logged_in_user[:id])
            @logged_in_user[:followers] = database.execute("select user_name from users inner join friends on friender_id = user_id where friended_id = ?", @logged_in_user[:id])
            database.results_as_hash = true
        else
            @logged_in_user[:id], session[:logged_in_user_id] = nil, nil
        end
        return nil
    end

    # Pulls information about a user from the database.
    #
    # @param [String] username, The username whose information will be pulled from the database.
    #
    # @see Model#open_db
    #
    # @return [Hash] Either an empty hash or result.
    def get_user(username)
        database = open_db()
        result = database.execute("select * from users where user_name = ?", username).first
        if result == nil
            return {}
        else
            return result
        end
    end

    # Creates an object able to compare passwords with already encrypted password_digests.
    #
    # @param [String] password_digest, A string containing an encrypted password.
    # 
    # @return [Object] A password object.
    def bcrypt(password_digest)
        return BCrypt::Password.new(password_digest)
    end

    # Pulls a list of users in the database, together with their data.
    #
    # @see Model#open_db
    #
    # @return [Hash]
    def user_list()
        database = open_db()
        return database.execute("select * from users")
    end

    # Checks whether a user is logged in.
    #
    # @return [String] If no user is logged in.
    # @return [NilClass] If user is logged in
    def logged_in()
        if @logged_in_user[:id] == nil
            return "You can't access this page without logging in."
        end
        return nil
    end

    # Delete on cascade-like functionality for when a user is removed from the database.
    #
    # @param [Array] users, List of all the users to be removed in the form of their integer user_id.
    #
    # @see Model#open_db
    #
    # @return [NilClass]
    def delete_users(users)
        database = open_db()
        users.each do |user_id|
            database.execute("delete from users where user_id = ?", user_id)
            database.execute("delete from playtime_records where user_id = ?", user_id)
            database.execute("delete from friends where friender_id = ? or friended_id = ?", user_id, user_id)
        end
    end

    # Registers a user to the database.
    #
    # @param [String] username, New user's username.
    # @param [String] password, New user's password.
    # @param [String] password_confirm, New user's confirmed password.
    # @param [Integer] osu_id, New user's osu! website profile id.
    #
    # @see Model#open_db
    # @see Model#get_user
    #
    # @return [String] If there is an error.
    # @return [NilClass] If method completes without errors.
    def register_user(username, password, password_confirm, osu_id)
        database = open_db()
        result = get_user(username)
        password_digest = result["password_digest"]
        user = result["user_id"]
        if params[:register] == nil
            if user != nil
                return "User #{username} is already being tracked."
            end
            database.execute("insert into users (osu_id, user_name) values (?,?)", osu_id, username)
        else
            if user["password_digest"] != nil
                return "User #{username} is already registered."
            end
            if password != password_confirm
                return "Password wasn't confirmed properly."
            end
            password_digest = BCrypt::Password.create(password)
            if user["user_id"] != nil
                database.execute("update users set password_digest = ? where user_id = ?", password_digest, result["user_id"])
            else
                database.execute("insert into users (osu_id, user_name, password_digest) values (?,?,?)", osu_id, username, password_digest)
            end
        end
        return nil
    end
    
    # Adds a log of a user's data from the osu! api.
    #
    # @param [Hash] params, parameters of the current http request.
    # @param [Class] pt, Playtime class instance.
    #
    # @see Model#open_db
    #
    # @return [String] If there is an error.
    # @return [NilClass] If method completes without errors.
    def update_user(params, pt)
        database = open_db()
        if database.execute("select * from users where user_name=?", params[:username]).first == nil
            return "user isn't registered to the database."
        else
            pt.getdb(params[:username], "", database)
            return nil
        end
    end

    # Creates an entry in the database of which user has friended which user. Also facilitates unfriending users.
    #
    # @param [String] username, Name of the person to be friended.
    #
    # @see Model#open_db
    # @see Model#get_user
    #
    # @return [String] If there is an error.
    # @return [NilClass] If method completes without errors.
    def friend(username)
        database = open_db()
        friender_id = @logged_in_user[:id]
        friended_id = get_user(username)["user_id"]
        result = database.execute("select * from friends where friender_id = ? and friended_id = ?", friender_id, friended_id).first
        
        
        if friended_id == friender_id
            return "Can't add or remove yourself as a friend!"
        end

        if result == nil
            database.execute("insert into friends (friender_id, friended_id) values (?, ?)", friender_id, friended_id)
            return nil
        end

        if result["friender_id"] == friender_id && result["friended_id"] == friended_id
            database.execute("delete from friends where friender_id = ? and friended_id = ?", friender_id, friended_id)
            return nil
        end
    end

    # Logs the last time specific actions took place, for example a failed login attempt or someone registering a user.
    #
    # @param [Hash] session, Sinatra persistent data.
    #
    # @return [NilClass]
    def log(session)
        session[:log] = Time.now()
        return nil
    end
end
