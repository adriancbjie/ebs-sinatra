class App < Sinatra::Base
  register Sinatra::Reloader
  set :sessions, true
  DataMapper.setup(:default, 'mysql://root:@localhost:3306/ebs')
  @oauth = Koala::Facebook::OAuth.new('183954298389323', 'ef1bd0f924d0260633e09c36aa9ca01c', "http://localhost:8080/process_facebook_login")
  app_oauth_access_token = @oauth.get_app_access_token
  products = {"-1" => ["beer","PURE BLONDE",5],
              "-2" => ["beer","VICTORIA BITTER",7],
              "-3" => ["liquor","ABSOLUT VODKA RUBY RED",8],
              "-4" => ["liquor","GREY GOOSE",9],
              "-5" => ["wine","2008 MIGUEL TORRES CABERNET SAUVIGNON",19],
              "-6" => ["wine","CHATEAU BERNADOTTE 2005",18]}
              # "-7" => ["food","FARMER PEANUTS"],
              # "-8" => ["food","BEEF TACO"],
              # "-9" => ["food","HOT DOGS"]}

  class User
    include DataMapper::Resource
    property :uid, Integer
    property :username, String, :key => true
    property :password, String
    property :created_at, DateTime
  end
  DataMapper.finalize
  DataMapper.auto_migrate!
  User.create(:username => "admin", :password => "admin", :uid => 0)
  for i in 1..100
    User.create(:username => "company#{i}", :password => "sapsucks", :uid => i)
  end
  
  get '/' do
    haml :index, :locals => {:message => ""}
  end

  post '/login' do
    @username = params[:username]
    pw = params[:pw]
    user = User.get(@username)
    if not user.nil?
      if pw == user.password
        session["user"] = user.username
        redirect_url = ""
        if @username == "admin"
          redirect_url = "http://localhost:8080/events_list"
        else
          redirect_url = "http://localhost:8080/main"
        end
        @oauth = Koala::Facebook::OAuth.new('183954298389323', 'ef1bd0f924d0260633e09c36aa9ca01c', "http://localhost:8080/process_facebook_login")
        session["oauth"] = @oauth
        redirect @oauth.url_for_oauth_code(:permissions => "publish_stream")
      end
    end
    haml :index, :locals => {:message => "you made a fucking error dude"}
  end

  get '/process_facebook_login' do
    code = params[:code]
    session["access_token"] = session["oauth"].get_access_token(code)
    redirect_url = ""
    if session["user"] == "admin"
      redirect "/events_list"
    else
      redirect "/main"
    end
    
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
    haml :create_event, :locals => {:products => products}
  end

  post "/create_event_to_facebook" do
    if session["user"].nil?
      haml :index, :locals => {:message => "you made a fucking error dude"}
    end
    event_name = params[:name]
    start_time = Date.strptime(params[:start_time], "%d/%m/%Y").to_time.to_i
    end_time = Date.strptime(params[:end_time], "%d/%m/%Y").to_time.to_i
    description = ""
    File.open('event_description.txt', 'r') do |f1|  
      while line = f1.gets
        description += line
      end
    end
    @graph = Koala::Facebook::API.new(app_oauth_access_token)
    event = @graph.put_connections("183954298389323", "events?name=#{event_name}&start_time=#{start_time}&end_time=#{end_time}&description=#{description}")

    puts "event_id #{event['id']}"
    total_num_attendees = params[:num_attendees].to_i
    message = ""
    chosen_products_array = params[:chosen_products]
    chosen_products_array.each do |p|
      message += "#{p} "
    end
    message += "~#{total_num_attendees}"
    @graph = Koala::Facebook::API.new(session["access_token"])
    @graph.put_connections(event['id'], "feed?message=#{message}")
    redirect "http://www.facebook.com/#{event['id']}"
  end
  get "/sapsucks/:event_id" do |id|
    if session["user"].nil?
      haml :index, :locals => {:message => "you made a fucking error dude"}
    end
    @graph = Koala::Facebook::API.new(session["access_token"])
    feeds = @graph.get_connections(id,"feed")
    
    #parse the feed data and aggregate them
    orders_array = []
    feeds.each do |f|
      choice_array = parse_message(f["message"])
      #remove last value and store it as total_num_attendees
      total_num_attendees = choice_array.last
      choice_array.delete(total_num_attendees)
      total_num_attendees = total_num_attendees.delete("]").delete("[").to_i
      orders_array << calculate_orders(choice_array,total_num_attendees)
      puts "hi #{orders_array}"
    end
    
    #aggregate all orders
    big_order = {}
    orders_array.each do |o|
      products.keys.each do |k|
        if not o[k].nil?
          #parse key into actual item key
          sap_item_key = products[k][2]
          if not big_order[sap_item_key].nil?
            big_order[sap_item_key] += o[k]
          else
            big_order[sap_item_key] = o[k]
          end
        end
      end
    end
    puts "big #{big_order}"
    
    # client = Savon::Client.new do
    #   wsdl.document = File.read("Invoke.wsdl")
    #   http.auth.basic "cslew", "handsome1"
    # end

    # response = client.request :yq1, :start_process do
    #   soap.namespaces["xmlns:SOAP-ENV"] = "http://schemas.xmlsoap.org/soap/envelope/"
    #   soap.namespaces["xmlns:xs"] = "http://www.w3.org/2001/XMLSchema"
    #   soap.namespaces["xmlns:xsi"] = "http://www.w3.org/2001/XMLSchema-instance"
    #   soap.xml = File.read("so.xml")
    #   puts soap.xml
    # end

    "will be done once the fucking sap webservice is ready"
  end
  
  def parse_message(message)
    array = []
    quantity = "[5]"
    for i in 0..(message.length - 2)
      if message[i] == "-"
        array << "-#{message[i+1]}"
      elsif message[i] == "["
        quantity = cut_quant(message)
      end  
    end
    array << quantity
    return array
  end
  
  def cut_quant(message)
    return message[message.index("["),message.index("]") - message.index("[") + 1]
  end
  
  def calculate_orders(chosen_products_array,total_num_attendees)
    products = {"-1" => ["beer","PURE BLONDE",5],
                "-2" => ["beer","VICTORIA BITTER",7],
                "-3" => ["liquor","ABSOLUT VODKA RUBY RED",8],
                "-4" => ["liquor","GREY GOOSE",9],
                "-5" => ["wine","2008 MIGUEL TORRES CABERNET SAUVIGNON",19],
                "-6" => ["wine","CHATEAU BERNADOTTE 2005",18]}
    carton = {"beer" => 12,
              "wine" => 24,
              "liquor" => 36}
    ratio = {"beer" => 6,
             "wine" => 3,
             "liquor" => 2}
    #logic to calculate algorithms
    #type of products array
    type_of_product = []
    chosen_products_array.each do |p|
      product = products[p][0]
      if not type_of_product.include? product
        type_of_product << product
      end
    end
    
    total_ratio = get_total_ratio(type_of_product)
    #brand values
    brand_values = {}
    type_of_product.each do |tp|
      count = 0
      chosen_products_array.each do |k|
        if products[k][0] == tp
          count += 1
        end
      end
      brand_values[tp] = count
    end
    
    orders = {}
    chosen_products_array.each do |p|
      p_type = products[p][0]
      
      # puts "ratio[p_type] = #{ratio[p_type]}"
      # puts "total_num_attendees = #{total_num_attendees}"
      # puts "total_ratio = #{total_ratio}"
      # puts "carton[p_type] = #{carton[p_type]}"
      # puts "brand_values[p_type] = #{brand_values[p_type]}"
      
      orders[p] = ((ratio[p_type] * total_num_attendees)/(total_ratio * carton[p_type])) / (brand_values[p_type])
    end
    return orders
  end
  
  get "/clear" do
    @graph = Koala::Facebook::API.new(app_oauth_access_token)
    events_hash = @graph.get_connections("183954298389323","events")
    events = []
    events_hash.each do |e|
      @graph.delete_object(e['id'])
    end
    "cleared events list"
  end
  
  get '/events_list' do
    if session["user"].nil?
      haml :index, :locals => {:message => "you made a fucking error dude"}
    end
    @graph = Koala::Facebook::API.new(app_oauth_access_token)
    events_hash = @graph.get_connections("183954298389323","events")
    events = []
    events_hash.each do |e|
      events << e
    end
    haml :events_list, :locals => {:events => events}
  end
  
  def parse_product_orders(feeds)
    codes = []
    feeds.each do |f|
       m = f['message']
       for i in (0..(m.size - 2))
         if m[i] == "-"
           codes << m[i+1]
         end
         # if m[i] == "~"
         #   num_ppl = m[i+1]
         # end
       end
     end
  end

  def get_total_ratio(type_of_product)
    if type_of_product.include? "beer" and type_of_product.include? "wine" and type_of_product.include? "liquor"
      total_ratio = 11
    elsif type_of_product.include? "beer" and type_of_product.include? "wine"
      total_ratio = 9
    elsif type_of_product.include? "wine" and type_of_product.include? "liquor"
      total_ratio = 5
    elsif type_of_product.include? "beer" and type_of_product.include? "liquor"
      total_ratio = 8
    elsif type_of_product.include? "beer"
      total_ratio = 6
    elsif type_of_product.include? "wine"
      total_ratio = 3
    elsif type_of_product.include? "liquor"
      total_ratio = 2
    end
  end
end
