require 'mongo_mapper'
class Author
  include MongoMapper::Document

  key :name, String, :required => true
  belongs_to :book

  timestamps!
end
