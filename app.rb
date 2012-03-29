require 'rubygems'
require 'sinatra'
require 'koala'
get '/' do
  # @test_users = Koala::Facebook::TestUsers.new(:app_id => "183954298389323", :secret => "ef1bd0f924d0260633e09c36aa9ca01c")
  # @test_users.create(true, "offline_access,read_stream")
  # @test_users.list
  @oauth = Koala::Facebook::OAuth.new('183954298389323', 'ef1bd0f924d0260633e09c36aa9ca01c', 'http://localhost:4567/')
  oauth_access_token = @oauth.get_app_access_token
  @graph = Koala::Facebook::API.new(oauth_access_token)
  # # in 1.1 or earlier, use GraphAPI instead of API
  # 
  # profile = @graph.get_object("183954298389323")
  # puts profile
  # puts profile["name"]
  # "hello #{profile['name']}"
  group_feed = @graph.get_connections("347308191987296", "feed")
  "showing #{group_feed}"
  # @graph.put_object("me", "feed", :message => "I am writing on my wall!")
  
end

