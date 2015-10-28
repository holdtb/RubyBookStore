require 'mongo_mapper'
class Meeting
  include MongoMapper::Document
  set_collection_name "meetings"

  key :seller, String
  key :buyer, String
  key :accepted, Boolean
  key :declined, Boolean
  key :location, String
  key :date, String
  key :time, String
  key :offer_id, ObjectId
  key :book_id, ObjectId

  timestamps!
end
