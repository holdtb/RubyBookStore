require 'rubygems'
require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/content_for'
require_relative './bookstore_helpers'
require 'mongo_mapper'

require_relative 'model/books'
require_relative 'model/orders'
require_relative 'model/archive'

class Bookstore < Sinatra::Base
  helpers Sinatra::ContentFor
  register Sinatra::Reloader
  helpers Bookstorehelper
  also_reload 'model/books'

  configure do
    MongoMapper.connection = Mongo::Connection.new("localhost", 27017)
    MongoMapper.database = "bookstore"
  end

  get '/' do
    erb :index
  end

  get '/buying' do
    @recent_books = Book.all
    erb :buying
  end

  get '/selling' do
    erb :selling
  end

end
