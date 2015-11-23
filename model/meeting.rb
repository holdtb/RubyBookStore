class Meeting
  include DataMapper::Resource

  property :id, Serial
  property :seller, String
  property :buyer, String
  property :accepted, Boolean
  property :declined, Boolean
  property :location, String
  property :date, String
  property :time, String

  property :created_at , DateTime
  property :offer_id, Integer
  property :book_id, Integer

  has 1, :offer

end
