require 'mongo_mapper'
class Author
  include MongoMapper::Document
  set_collection_name "authors"

  key :name, String, :required => true
  belongs_to :book

end
