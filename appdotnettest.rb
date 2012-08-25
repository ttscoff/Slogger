#!/usr/bin/ruby

require File.dirname(File.expand_path(__FILE__)) + '/lib/oauth'

@callback_url = "http://127.0.0.1:3000/oauth/callback"
@consumer = OAuth::Consumer.new("Jqav7kPZhmXkcJ7URCe75b5AQU7tHaFs","JjacJqjqvR8xD936UeeunxwzQdg3PjbA", :site => "https://alpha.app.net")
'https://alpha.app.net/oauth/access_token?client_id=Jqav7kPZhmXkcJ7URCe75b5AQU7tHaFs&client_secret=JjacJqjqvR8xD936UeeunxwzQdg3PjbA'
@request_token = OAuth::AccessToken.new(@consumer)
@request_token = @consumer.get_access_token(@request_token)
# res = @request_token.request(:post, "/oauth/authenticate?client_id=Jqav7kPZhmXkcJ7URCe75b5AQU7tHaFs&response_type=code&redirect_uri=&scope=stream")
p res
# session[:request_token] = @request_token
# redirect_to @request_token.authorize_url(:oauth_callback => @callback_url)
