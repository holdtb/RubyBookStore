class Author
  include DataMapper::Resource

  property :id, Serial
  property :name, String, :required => true
  property :created_at , DateTime

  belongs_to :book
end
