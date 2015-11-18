
require 'rubygems'
require 'bundler'
require 'sinatra'
require 'rspec'
require 'rack/test'
require 'pry'
require_relative '../bookstore.rb'

# set test environment
Sinatra::Base.set :environment, :test
Sinatra::Base.set :run, false
Sinatra::Base.set :raise_errors, true
Sinatra::Base.set :logging, false

#module RSpecMixin
#  include Rack::Test::Methods
#  def app() Bookstore.new end
#end

RSpec.configure do |c|
   #c.include RSpecMixin
   c.include Rack::Test::Methods
end
