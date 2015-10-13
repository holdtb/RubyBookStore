require 'mongo_mapper'

class Book
  include MongoMapper::Document
  set_collection_name "BOOKS"

  key :title, String, :required => true
  key :isbn, String, :required => true
  key :publisher, String
  key :year, String
  key :edition, String
  key :description, String
  key :pages, Integer
  key :avgRating, Float
  key :thumbnail, String
  
  many :posts
  many :authors
end
