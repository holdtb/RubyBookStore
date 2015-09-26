require 'rubygems'
require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'mongo_mapper'
require 'uri'
require 'net/http'
require 'httparty'
require 'json'

require_relative './bookstore_helpers'
require_relative './lib/cas/cas_helpers'
require_relative 'model/books'
require_relative 'model/orders'
require_relative 'model/archive'
require_relative 'model/authors'

class Bookstore < Sinatra::Base
  helpers Sinatra::ContentFor
  register Sinatra::Reloader
  use Rack::Session::Cookie, :secret => 'bookstore'

  helpers Bookstorehelper
  helpers CasHelpers
  also_reload 'model/books'


  configure do
    MongoMapper.connection = Mongo::Connection.new("localhost", 27017)
    MongoMapper.database = "bookstore"
  end

  before do
    process_cas_login(request, session)
  end


  get '/' do
    erb :index
  end

  get '/buying' do
    require_authorization(request, session) unless logged_in?(request, session)
    @user = session[:cas_user]

    @recent_books = Book.all
    erb :buying
  end

  post '/buying' do
    @book_isbns = params[:isbn] if params[:isbn]
    @book << Book.where(:title => params[:title]) if params[:title]
    @book_isbns << @book.isbn if params[:title]
    @book << Book.where(:author => params[:author]) if params[:author]
    @book_isbns << @book.isbn if params[:author]
    @book_isbns.each do |isbn|
      @orders << Orders.where(:isbn => isbn)
    end
    redirect '/not_found' unless @orders
    redirect '/search_results'
  end

  get '/selling' do
    require_authorization(request, session) unless logged_in?(request, session)
    @user = session[:cas_user]

    erb :selling
  end

  post '/selling' do
    require_authorization(request, session) unless logged_in?(request, session)
    @user = session[:cas_user]

    isbn = find_isbn(params)
    scrape(params) if isbn.nil?
    #create_listing(book)
  end

  get '/not_found' do
    erb :not_found
  end

  def find_isbn(params)
    puts "Finding isbns..."
    isbn = Book.first("isbn" => params[:isbn]) if params[:isbn] != ""
    return isbn if isbn

    # if params[:author] != "" && params[:title] != "" then
    #   author = Author.where(:author => params[:author])
    # end
    return nil
  end

  def scrape(params)
    puts "Scraping..."
    if params[:isbn] != "" then
      url = "https://www.googleapis.com/books/v1/volumes?q=isbn:#{params[:isbn]}"
      response = HTTParty.get(url, :verify => false)
      parsed_response = JSON.parse(response.body)
    end
    add_to_db(parsed_response)
  end

  def add_to_db(json)
    puts "Adding to db..."
    volume_info = json['items'][0]['volumeInfo']
    title = volume_info['title']
    isbn = volume_info['industryIdentifiers'][0]['identifier']
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

  def create_listing(isbn)
    puts "Creating listing..."
  end

end
