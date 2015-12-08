class Book
  include DataMapper::Resource

  property :id, Serial
  property :title, String, :required => true
  property :isbn, String, :required => true
  property :publisher, String
  property :year, String
  property :description, Text
  property :pages, Integer
  property :avgRating, Float
  property :thumbnail, Text
  property :created_at , DateTime

  #In the database,
  # this adds a post_id property to a post table.
  has n, :posts
  has n, :authors
  has n, :meetings
end
