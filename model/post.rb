require 'mongo_mapper'
class Post
  include MongoMapper::Document
  set_collection_name "POSTINGS"

  key :book_id, ObjectId
  key :seller, String
  key :price, Float
  key :condition, String

  many :offers
  timestamps!
end
