require 'rubygems'
require "sinatra"
require "instagram"

CALLBACK_URL = "http://localhost:4567/oauth/callback"

Instagram.configure do |config|
  config.client_id = "3b878d6b67444f3c8bac914655bfe582"
  config.client_secret = "9cd3c532cd6a495890b2d2850647c8d1"
end

def exit!
  Process.kill "TERM", Process.pid
end

get "/" do
  '<a href="/oauth/connect">Connect with Instagram</a>'
end

command = 'open http://localhost:4567'
output = `#{command}`

get "/oauth/connect" do
  redirect Instagram.authorize_url(:redirect_uri => CALLBACK_URL)
end

get "/code/:code" do
  "#{params[:code]}"
end

get "/oauth/callback" do
  response = Instagram.get_access_token(params[:code], :redirect_uri => CALLBACK_URL)
  exit!
  "<h2>#{response.access_token}</h2><br></p>Head back to the terminal and paste in the code above</p>"
end