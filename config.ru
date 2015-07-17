require 'rubygems'
require 'sinatra'

Bundler.require

map '/' do
  run Bookstore
end
