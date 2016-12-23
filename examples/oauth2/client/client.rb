require 'sinatra'
require 'rest-client'
require "uuid"

set :bind, '0.0.0.0'
enable :sessions
set :session_secret, '*&(^B234'
set :port, 3001

GATEWAY = ENV['GATEWAY'] || "localhost:8080"
CLIENT_ID = ENV['CLIENT_ID']
CLIENT_SECRET = ENV['CLIENT_SECRET']
REDIRECT_URI = ENV['REDIRECT_URI'] || "http://localhost:3001/callback"
AUTHORIZE_ENDPOINT = "http://#{GATEWAY}/authorize"
TOKEN_ENDPOINT = "http://#{GATEWAY}/oauth/token"

get("/") do	
	if params[:action] == "get_token"
		get_token(params[:code])
	end
	erb :root
end

get("/callback") do
	session[:code] = params[:state] == session[:state] ? params[:code] : "error: state does not match"

	@code = session[:code]
	erb :root
end