Dir["../../model/*.rb"].each {|file| require file }
require 'json'
require 'httparty'

module GoogleBookScraper
  def scrape_and_find(isbn)
    isbn.isbn13 if isbn.valid?
    book = find_book_by_isbn(isbn)
    if book.nil? then
      scrape(isbn)
    end
    book = find_book_by_isbn(isbn)
  end

  def find_book_by_isbn(isbn)
    return Book.first("isbn" => isbn) if isbn != "" && Book.first("isbn" => isbn)
    return nil
  end

  def scrape(isbn)
    if isbn != "" then
      url = "https://www.googleapis.com/books/v1/volumes?q=isbn:#{isbn}"
      response = HTTParty.get(url, :verify => false)
      parsed_response = JSON.parse(response.body)
    end
    add_to_db(parsed_response)
  end

  def add_to_db(json)
    volume_info = json['items'][0]['volumeInfo']
    title = volume_info['title']
    isbn_holder = volume_info['industryIdentifiers'].select{|n| n['type'] == "ISBN_13"}.first
    isbn = isbn_holder['identifier']
    publisher = volume_info['publisher']
    year = volume_info['publishedDate']
    description = volume_info['description']
    pages = volume_info['pageCount']
    avg_rating = volume_info['averageRating']
    thumbnail = volume_info['imageLinks']['thumbnail']
    authors = volume_info['authors']

    book = Book.create({
      :title => title,
      :isbn => isbn,
      :publisher => publisher,
      :year => year,
      :description => description,
      :pages => pages,
      :avgRating => avg_rating,
      :thumbnail => thumbnail,
      :authors => authors.map{|a| Author.new(:name => a)}
    })
  end

end
