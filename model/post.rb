class Post
  include DataMapper::Resource

  property :id, Serial
  property :seller, String
  property :price, Integer
  property :condition, String
  property :verified_book, Boolean
  property :created_at , DateTime

  property :book_id, Integer

  belongs_to :book
  has n, :offers
end
