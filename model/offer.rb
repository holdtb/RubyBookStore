class Offer
  include DataMapper::Resource

  property :id, Serial
  property :buyer, String, :required => true
  property :seller, String, :required => true
  property :price, Integer, :required => true
  property :active, Boolean
  property :accepted, Boolean
  property :created_at , DateTime

  belongs_to :post
end
