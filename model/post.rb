require 'mongo_mapper'
class Post
  include MongoMapper::Document
  set_collection_name "POSTS"


  key :seller, String
  key :price, Float
  key :condition, String

  key :book_id, ObjectId
  belongs_to :book
  many :offers
  timestamps!
end
