$:.unshift(".")

require "bundler/setup"
require "app"

if ENV["RACK_ENV"].eql?("development")
  $stdout.sync = true
  Logging.logger = Logger.new($stdout, Logger::INFO)
end

map GitNotebook.pinion.mount_point do
  run GitNotebook.pinion
end

map "/" do
  run GitNotebook
end
