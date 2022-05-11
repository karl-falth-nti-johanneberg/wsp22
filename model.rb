module Model
    def open_db()
        database = SQLite3::Database.new "db/playtime.db"
        database.results_as_hash = true
        return database
    end

    def before_every_route()
        database = open_db()
        @logged_in_user = {}
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
    end

    def get_user(username)
        database = open_db()
        result = database.execute("select * from users where user_name = ?", username).first
        return result
    end

    def bcrypt(password_digest)
        return BCrypt::Password.new(password_digest)
    end

    def current_role()
        database = open_db()
        return database.execute("select role from users where user_id = ?", @logged_in_user[:id]).first
    end

    def user_list()
        database = open_db()
        return database.execute("select * from users")
    end

    def logged_in?()
        if @logged_in_user[:id] == nil
            return "You can't access this page without logging in."
        end
    end

    def delete_users(users)
        database = open_db()
        users.each do |user_id|
            database.execute("delete from users where user_id = ?", user_id)
            database.execute("delete from playtime_records where user_id = ?", user_id)
            database.execute("delete from friends where friender_id = ? or friended_id = ?", user_id, user_id)
        end
    end

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
    end
    
    def update_user(params, pt)
        database = open_db()
        if database.execute("select * from users where user_name=?", params[:username]).first == nil
            "user isn't registered to the database."
        else
            pt.getdb(params[:username], "", database)
            redirect '/users/' + params[:username]
        end
    end

    def friend(username)
        database = open_db()
        friender_id = @logged_in_user[:id]
        friended_id = database.execute("select user_id from users where user_name = ?", username).first["user_id"]
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
end
