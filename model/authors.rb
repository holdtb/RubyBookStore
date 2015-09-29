require 'mongo_mapper'
class Author
  include MongoMapper::Document
  set_collection_name "AUTHORS"

  key :name, String, :required => true
  belongs_to :book

  timestamps!
end
