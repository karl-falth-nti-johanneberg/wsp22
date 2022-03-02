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
    def combinename(user_list_with_data)
        output = {}
        user_list_with_data.each_with_index do |data, i|
            if output[data["user_name"]] == nil
                output[data["user_name"]] = [[data["date_time"], data["playtime"]]]
            elsif output[data["user_name"]]
                output[data["user_name"]].append([data["date_time"], data["playtime"]])
            end
        end
        return output
    end
    def extrapolate(data)
        # output ska innehålla: skillnad i speltid mellan två datapunkter / skillnad i faktisk tid mellan två datapunkter.
        #                       senaste veckans speltid.
        #                       speltid per dag i snitt.
        output = {"percent" => nil, "last_week" => nil, "average_day" => nil}

        # skillnad i speltid mellan tidigaste och senaste datapunkten / skillnad i faktisk tid mellan tidigaste och senaste datapunkten.
        date_time_first = data[0][0].split(/[ \/:]/)
        date_time_last  = data[-1][0].split(/[ \/:]/)
        time_difference = Time.new(date_time_last[0],date_time_last[1],date_time_last[2],date_time_last[3],date_time_last[4],date_time_last[5]).to_i - Time.new(date_time_first[0], date_time_first[1], date_time_first[2], date_time_first[3], date_time_first[4], date_time_first[5]).to_i
        playtime_difference = data[-1][1] - data[0][1]
        output["percent"] = ((playtime_difference.to_f / time_difference.to_f)*100)

        # senaste veckans speltid.
        puts date_time_last, time_difference
        date_time_week = date_time_last
        i = -1
        if time_difference < 604800
            i = 0
            date_time_week = data[i]
        else
            until Time.new(date_time_last[0], date_time_last[1], date_time_last[2], date_time_last[3], date_time_last[4], date_time_last[5]).to_i - Time.new(date_time_week[0], date_time_week[1], date_time_week[2], date_time_week[3], date_time_week[4], date_time_week[5]).to_i >= 604800
                i += -1
                date_time_week = data[i]
            end
        end
        playtime_last = data[-1][1]
        playtime_week = data[i][1]
        time_difference = Time.new(date_time_last[0],date_time_last[1],date_time_last[2],date_time_last[3],date_time_last[4],date_time_last[5]).to_i - Time.new(date_time_week[0], date_time_week[1], date_time_week[2], date_time_week[3], date_time_week[4], date_time_week[5]).to_i
        week_factor = 604800 / time_difference
        output["last_week"] = (playtime_last - playtime_week) * week_factor

        # speltid per dag i snitt.
        output["average_day"] = playtime_difference / ((Time.new(date_time_last[0],date_time_last[1],date_time_last[2],date_time_last[3],date_time_last[4],date_time_last[5]).to_i - Time.new(date_time_first[0], date_time_first[1], date_time_first[2], date_time_first[3], date_time_first[4], date_time_first[5]).to_i) / 86400)
        return output
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