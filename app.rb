class App < Sinatra::Base
  register Sinatra::Reloader
  set :sessions, true
  DataMapper.setup(:default, 'mysql://root:@localhost:3306/ebs')
  @oauth = Koala::Facebook::OAuth.new('183954298389323', 'ef1bd0f924d0260633e09c36aa9ca01c', 'http://localhost:9292/facebook')
  oauth_access_token = @oauth.get_app_access_token
  oauth_access_token = "AAACnTjKcQ0sBAJkLxhVUTWaHjUL2wOROyovZCD2YL5IOQ3jKbaS4oVmYKJ4YOMUxOn3SRXcYJtrx6zWvzZBb8aq8XpKAFTr8qRnM7LtQZDZD"
  
  configure do
    @event_id = ""
  end

  products = {"-1" => ["beer","PURE BLONDE"],
              "-2" => ["beer","VICTORIA BITTER"],
              "-3" => ["liquor","ABSOLUT VODKA RUBY RED"],
              "-4" => ["liquor","GREY GOOSE"],
              "-5" => ["wine","2008 MIGUEL TORRES CABERNET SAUVIGNON"],
              "-6" => ["wine","CHATEAU BERNADOTTE 2005"],
              "-7" => ["food","FARMER PEANUTS"],
              "-8" => ["food","BEEF TACO"],
              "-9" => ["food","HOT DOGS"]}

  class User
    include DataMapper::Resource
    property :uid, Integer
    property :username, String, :key => true
    property :password, String
    property :created_at, DateTime
  end
  DataMapper.finalize
  DataMapper.auto_migrate!

  User.create(:username => "adrian", :password => "asd", :uid => 1)
  get '/' do
    haml :index, :locals => {:message => "Welcome"}
  end

  post '/login' do
    @username = params[:username]
    pw = params[:pw]
    user = User.get(@username)
    if not user.nil?
      if pw == user.password
        puts "password is #{pw}"
        session["user"] = user.username
        redirect '/main'
      end
    end
    haml :index, :locals => {:message => nil}
  end

  get '/main' do
    if session["user"].nil?
      haml :index, :locals => {:message => "you made a fucking error dude"}
    end
    haml :main
  end

  get '/logout' do
    session["user"] = nil
    haml :index, :locals => {:message => "you've been successfully logged out"}
  end

  get '/create_event' do
    haml :create_event
  end

  post "/create_event_to_facebook" do
    event_name = params[:name]
    start_time = Date.strptime(params[:start_time], "%d/%m/%Y").to_time.to_i
    end_time = Date.strptime(params[:end_time], "%d/%m/%Y").to_time.to_i
    description = ""
    File.open('event_description.txt', 'r') do |f1|  
      while line = f1.gets
        description += line
      end
    end
    puts description
    @graph = Koala::Facebook::API.new(oauth_access_token)
    event = @graph.put_connections("183954298389323", "events?name=#{event_name}&start_time=#{start_time}&end_time=#{end_time}&description=#{description}")

    # puts "hi #{@event_id}"
    # woohoo = 'asdasljasjdn -1 ,asnkjangkja -2 ,asnkjgana -3'
    # @graph.put_connections(event['id'], "feed?message=#{woohoo}")
    # @graph.put_connections(event['id'], "feed?message=#{woohoo}")
    # @graph.put_connections(event['id'], "feed?message=#{woohoo}")
    # feeds = @graph.get_connections(event['id'],"feed")
  end
  
  get "/sapsucks" do

     # codes = ""
     # num_ppl = 5
     # feeds.each do |f|
     #   m = f['message']
     #   for i in (0..(m.size - 2))
     #     if m[i] == "-"
     #       puts m[i+1]
     #     end
     #     if m[i] == "~"
     #       num_ppl = m[i+1]
     #     end
     #   end
     # end
  end
  
end
