require 'mongo_mapper'
class Offer
  include MongoMapper::Document
  set_collection_name "offers"

  key :buyer, String, :required => true
  key :seller, String, :required => true
  key :price, Integer, :required => true
  key :active, Boolean
  key :accepted, Boolean

  belongs_to :post
  timestamps!
end
