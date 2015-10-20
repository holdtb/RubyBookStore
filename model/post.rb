require 'mongo_mapper'
class Post
  include MongoMapper::Document
  set_collection_name "posts"


  key :seller, String
  key :price, Integer
  key :condition, String

  key :book_id, ObjectId
  belongs_to :book
  many :offers
  timestamps!
end
