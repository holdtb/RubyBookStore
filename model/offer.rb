require 'mongo_mapper'
class Offer
  include MongoMapper::Document
  set_collection_name "offers"

  key :buyer, String, :required => true
  key :seller, String, :required => true
  key :price, Integer, :required => true

  belongs_to :post
  timestamps!
end
