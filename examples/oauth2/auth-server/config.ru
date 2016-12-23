require './auth-server'
require 'dotenv'

Dotenv.load
run Sinatra::Application
