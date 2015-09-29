require 'rubygems'
require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'mongo_mapper'
require 'uri'
require 'net/http'
require 'httparty'
require 'json'
require 'lisbn'

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
    book_for_sale = find_book_for_sale(params)
    #create_listing(book)
  end

  get '/selling/confirm' do
    require_authorization(request, session) unless logged_in?(request, session)
    @user = session[:cas_user]

    @condition = session[:condition]
    @price = session[:price]
    @book = Book.find(session[:book_id])
    @authors = Author.where(:book_id => session[:book_id]).all

    erb :sell_book_confirm
  end

  get '/selling/sell' do

  end

  get '/not_found' do
    erb :not_found
  end

  def find_book_for_sale(params)
    if(params[:isbn] != "") then
      stripped_isbn = params[:isbn].gsub('-','')
      isbn = Lisbn.new(stripped_isbn)
      book = scrape_and_find(isbn)
      confirm_listing(book._id, params[:price], params[:condition])
    end
    #TODO -- add support for author and title search
  end

  def confirm_listing(book_id, price, condition)
    require_authorization(request, session) unless logged_in?(request, session)
    @user = session[:cas_user]
    session[:condition] = condition
    session[:price] = price
    session[:book_id] = book_id
    redirect '/selling/confirm'
  end

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

  def create_listing(isbn)
    puts "Creating listing..."
  end

end
