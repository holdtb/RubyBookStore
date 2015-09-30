require 'mongo_mapper'
class Offer
  include MongoMapper::Document
  set_collection_name "OFFERS"

  key :buyer, String, :required => true
  key :seller, String, :required => true

  belongs_to :order
  timestamps!
end
