require 'rubygems'
require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'mongo_mapper'
require 'lisbn'
require_relative './lib/cas/cas_helpers'
require_relative './lib/util/google_books_scraper'
Dir["./model/*.rb"].each {|file| require file }

class Bookstore < Sinatra::Base
  set :public_folder, 'public'
  helpers Sinatra::ContentFor
  register Sinatra::Reloader
  use Rack::Session::Cookie, :secret => 'bookstore'
  helpers GoogleBookScraper
  helpers CasHelpers

  configure do
    MongoMapper.connection = Mongo::Connection.new("localhost", 27017)
    MongoMapper.database = "bookstore"
  end

  before do
    process_cas_login(request, session)
    require_authorization(request, session) unless logged_in?(request, session)
    @user = session[:cas_user]
  end

  get '/' do
    erb :index
  end

  get '/buying' do
    @recent_books = Book.all
    erb :buying
  end

  post '/buying' do
    # book_isbns = params[:isbn] if params[:isbn]
    # book << Book.where(:title => params[:title]) if params[:title]
    # book_isbns << book.isbn if params[:title]
    # book << Book.where(:author => params[:author]) if params[:author]
    # book_isbns << book.isbn if params[:author]
    # book_isbns.each do |isbn|
    #   @orders << Orders.where(:isbn => isbn)
    # end
    # redirect '/not_found' unless @orders
    # redirect '/search_results'
  end

  get '/selling' do
    erb :selling
  end

  post '/selling' do
    book_for_sale = find_book_for_sale(params)
  end

  get '/selling/confirm' do
    @condition = session[:condition]
    @price = session[:price]
    @book = Book.find(session[:book_id])
    @authors = Author.where(:book_id => session[:book_id]).all

    erb :sell_book_confirm
  end

  get '/selling/sell' do
    post = Post.new(
                   :book_id => session[:book_id],
                   :seller => @user,
                   :price => session[:price],
                   :condition => session[:condition])

    post.save!
    redirect '/selling/success'
  end

  get '/selling/success' do
    erb :sale_success
  end

  get '/not_found' do
    erb :not_found
  end

  def find_book_for_sale(params)
    if(params[:isbn] != "") then
      stripped_isbn = params[:isbn].gsub('-','').strip
      isbn = Lisbn.new(stripped_isbn)
      book = scrape_and_find(isbn)
      redirect '/error' if book.nil?
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

end
