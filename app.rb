require 'socket'
require 'sinatra'
require 'pg'
require 'redis'

$stdout.sync = true

get '/' do
  "Hello from Flynn on port #{ENV['PORT']} from container #{Socket.gethostname}\n"
end
