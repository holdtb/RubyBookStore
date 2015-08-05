require 'mongo_mapper'

class Book
  include MongoMapper::Document
  set_collection_name "Books"

  key :title, String, :required => true
  key :isbn, String, :required => true
  key :authors, Array, :required => true
  key :publisher, String
  key :thumbnail, String
  timestamps!
end
