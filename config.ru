require 'rubygems'
require 'sinatra'
require 'bundler'
require 'pry'
require 'pry-byebug'
require_relative './bookstore'

Bundler.require

map '/' do
  run Bookstore
end
