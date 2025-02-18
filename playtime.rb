require 'http'
require 'Scruffy'

# Class that establishes a connection to the osu! game api.
# Also pulls data from the api as well as extrapolates it and generates graphs.
#
class Playtime
    @@client_id = 12307
    @@client_secret = "82Wwjem9FHYMKrxXDy39D4lg0vaJfKH9Hy25eOW5"

    # Establish connection with osu! servers, providing access to user data.
    # Mainly playtime will be gathered, but also usernames and user id's.
    #
    # @return [Boolean] true if no errors.
    def initialize()
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

    # Get playtime in seconds or hours for a specified user.
    #
    # @param [String, Integer] user, Either String or Integer, represents an osu user's username or id.
    # @param [String] format, Decides what is included in the output.
    #
    # @return [Array] Mainly three elements, if format == hours only two elements.
    def get(user, format)
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
        playtime, username, user_id = response.parse["statistics"]["play_time"], response.parse["username"], response.parse["id"]
        if format == "hours"
            playtime = "%02d:%02d:%02d" % [playtime/3600, (playtime/60)%60, playtime%60]
            return [playtime, username]
        end
        return [playtime, username, user_id]
    end

    # Gets new data about osu player and puts it in the database.
    #
    # @param [String, Integer] user, Either String or Integer, represents an osu user's username or id.
    # @param [String] format, Decides what is included in the output.
    # @param [Object] db, Database object.
    #
    # @return [NilClass]
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
        return nil
    end

    # Creates hash with each user's full data history.
    #
    # @param [Object] database, Database object.
    #
    # @return [Hash] Contains the user's playtime history.
    def combinename(database)
        input = {}
        output = {}
        database.execute("select user_name, date_time, playtime from users inner join playtime_records on users.user_id = playtime_records.user_id order by playtime_records.id asc").each_with_index do |data, i|
            if input[data["user_name"]] == nil
                input[data["user_name"]] = [[data["date_time"], data["playtime"]]]
            elsif input[data["user_name"]]
                input[data["user_name"]].append([data["date_time"], data["playtime"]])
            end
        end
        input.each do |key, value|
            output[key] = [value[0]]
            i = 1
            until i == value.length-1 || value.length-1 == 0
                if value[i-1][1] != value[i][1]
                    output[key].append(value[i])
                end
                i += 1
            end
        end
        return output
    end

    # Function for extrapolating data from the osu! playtime records.
    #
    # @param [Array] data, Array with data about a user.
    #
    # @return [Hash] output ska innehålla: skillnad i speltid mellan två datapunkter / skillnad i faktisk tid mellan två datapunkter.
    # senaste veckans speltid.
    # speltid per dag i snitt.
    def extrapolate(data)
        output = {"percent" => nil, "last_week" => nil, "average_day" => nil}
        return nil if data == nil 
        # skillnad i speltid mellan tidigaste och senaste datapunkten / skillnad i faktisk tid mellan tidigaste och senaste datapunkten.
        # vill ha funktionalitet för att själv kunna välja vilka datapunkter som ska användas.
        date_time_first = data[0][0]
        date_time_last  = data[-1][0]
        time_difference = DateTime.parse(date_time_last).to_time.to_i - DateTime.parse(date_time_first).to_time.to_i
        playtime_difference = data[-1][1] - data[0][1]
        output["percent"] = [((playtime_difference.to_f / time_difference.to_f)*100), "since: " + date_time_first]

        # senaste veckans speltid.
        date_time_week = date_time_last
        i = -1
        if time_difference < 604800
            i = 0
            date_time_week = data[i][0]
        else
            until DateTime.parse(date_time_last).to_time.to_i - DateTime.parse(date_time_week).to_time.to_i > 604800
                i += -1
                date_time_week = data[i][0]
            end
        end
        playtime_last = data[-1][1]
        playtime_week = data[i][1]
        time_difference = DateTime.parse(date_time_last).to_time.to_i - DateTime.parse(date_time_week).to_time.to_i
        week_factor = 604800.0 / time_difference
        output["last_week"] = (playtime_last - playtime_week) * week_factor / 3600

        # speltid per dag i snitt.
        output["average_day"] = playtime_difference / ((DateTime.parse(date_time_last).to_time.to_i - DateTime.parse(date_time_first).to_time.to_i) / 86400.0) / 3600
        return output
    end
    # Function which generates a png format image containing a graph of a user's playtime history.
    #
    # @param [String] user, Username of the account whose data is being graphed.
    # @param [Array] data, Array with data about a user.
    #
    # @return [String] path to generated image.
    def graphdata(user, data)
        return "/img/missing_data.png" if data == nil 
        data = data[1..-1] if data.length%2 == 0 && data.length > 2
        points = []
        point_markers = []
        data.each_with_index do |d, i|
            points.append(d[1]/3600)
            if i%2 == 0
                point_markers.append(d[0][5..9])
            else
                point_markers.append("")
            end
        end
        point_markers = [data[0][0][5..9], data[1][0][5..9]] if data.length == 2
        graph = Scruffy::Graph.new(:title => user,:point_markers => point_markers)
        graph.add(:line, "Playtime, h", points)
        path = "./public/misc/#{user}-#{Dir["./public/misc/#{user}*"].size}.png"
        graph.render(:size => [640,480], :as => 'PNG', :to => path)
        return path[8..-1]
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