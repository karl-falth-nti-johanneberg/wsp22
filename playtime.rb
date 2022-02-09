require 'http'
require 'sqlite3'
class Playtime
    @@client_id = 12307
    @@client_secret = "82Wwjem9FHYMKrxXDy39D4lg0vaJfKH9Hy25eOW5"
    def initialize() # Establish connection with osu! servers, providing access to user data. Mainly playtime will be gathered, but also usernames and user id's 
        url = "https://osu.ppy.sh/oauth/token"
        raise "Client id isn't an integer" if @@client_id.class != Integer
        params = {client_id:@@client_id, client_secret:@@client_secret, grant_type:"client_credentials", scope:"public"}
        response = HTTP.post(url, :json => params)
        if response.code.to_i == 200
            puts "Access token received."
        else
            raise "Couldn't inizialize:" + response.code.to_s
        end
        @access_token = response.parse["access_token"]
        return true
    end
    def get(user, format) # Get playtime in seconds or hours for a specified user.
        if user.class == String
            url = "https://osu.ppy.sh/api/v2/users/" + user
            response = HTTP.auth("Bearer " + @access_token).get(url, :params => {:key => "username"})    
        elsif user.class == Integer
            url = "https://osu.ppy.sh/api/v2/users/#{user}"
            response = HTTP.auth("Bearer " + @access_token).get(url, :params => {:key => "id"})
        else
            raise "Input isn't either an id or username."
        end
        raise "Nonexistant user" if response.code != 200
        playtime, username, user_id = response.parse["statistics"]["play_time"], response.parse["username"], response.parse["user_id"]
        if format == "hours"
            playtime = "%02d:%02d:%02d" % [playtime/3600, (playtime/60)%60, playtime%60]
            return [playtime, username]
        end
        return [playtime, username, user_id]
    end
    def getdb(user, format, db)
        if user.class == String
            url = "https://osu.ppy.sh/api/v2/users/" + user
            response = HTTP.auth("Bearer " + @access_token).get(url, :params => {:key => "username"})    
        elsif user.class == Integer
            url = "https://osu.ppy.sh/api/v2/users/#{user}"
            response = HTTP.auth("Bearer " + @access_token).get(url, :params => {:key => "id"})
        else
            raise "Input isn't either an id or username."
        end
        raise "Nonexistant user" if response.code != 200
        playtime, username, osu_id = response.parse["statistics"]["play_time"], response.parse["username"], response.parse["id"]
        date_time = Time.now.strftime("%Y/%m/%d %H:%M:%S")
        if format == "hours"
            playtime = "%02d:%02d:%02d" % [playtime/3600, (playtime/60)%60, playtime%60]
        end
        user_id = db.execute("select user_id from users where osu_id = ?", osu_id).first["user_id"]
        db.execute("insert into playtime_records (user_id, date_time, playtime) values (? ,? ,?)", user_id, date_time, playtime)
    end
end
# print "client id:"
# client_id = gets.chomp.to_i
# print "client secret:"
# client_secret = gets.chomp

# session = Playtime.new(client_id, client_secret)

# print "User id:"
# user = gets.chomp.to_i
# print session.get(user)