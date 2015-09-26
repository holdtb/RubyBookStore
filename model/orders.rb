require 'mongo_mapper'
class Order
  include MongoMapper::Document
  set_collection_name "ORDERS"

  key :book_id, ObjectId
  key :seller_username, String
  key :buyer_username, String
  key :location, String
  key :price, Float
  key :condition, String

  many :offers

  timestamps!
end
