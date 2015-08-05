require 'mongo_mapper'
class Order
  include MongoMapper::Document
  set_collection_name "Orders"

  key :book_id, ObjectId
  key :seller_username, String
  key :buyer_username, String
  key :location, String
  key :offer_ids, Array
  key :price, Float
  key :condition, String

  timestamps!

end
