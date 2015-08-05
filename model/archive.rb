class Archive
  include MongoMapper::Document
  set_collection_name "ARCHIVE"

  key :orders, Array
  timestamps!
  
  # key :book_id, ObjectID
  # key :seller_username, String
  # key :buyer_username, String
  # key :location, String
  # key :offer_ids, Array
  # key :price, Float
  # key :condition, String
end
