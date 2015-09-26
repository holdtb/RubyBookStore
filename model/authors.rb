require 'mongo_mapper'
class Author
  include MongoMapper::Document
  set_collection_name "AUTHORS"

  key :author_id, ObjectId
  key :isbn, String, required => true
  key :author, String, required => true

  belongs_to :book

  timestamps!
end
