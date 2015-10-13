require 'rubygems'
require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'sinatra/formkeeper'
require 'mongo_mapper'
require 'lisbn'
require_relative './lib/cas/cas_helpers'
require_relative './lib/util/google_books_scraper'
Dir["./model/*.rb"].each {|file| require file }

class Bookstore < Sinatra::Base
  set :public_folder, 'public'
  helpers Sinatra::ContentFor
  register Sinatra::Reloader
  register Sinatra::FormKeeper
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
    @recent_posts= Post.all
    @authors = []
    @recent_posts.each do |post|
      authors = Author.where(:book_id => post.book_id).fields(:name).all
      @authors << authors.map(&:name)
    end
    erb :"buying/index"
  end

  post '/buying' do
    book_isbns = []
    if params[:isbn] != "" then
      stripped_isbn = params[:isbn].gsub('-','').strip
      lisbn = Lisbn.new(stripped_isbn)
      isbn = lisbn.isbn13.to_s if lisbn.valid?
      book_isbns << isbn if isbn
    end

    book = Book.where(:title => /#{Regexp.escape(params[:title])}/).all if params[:title] != ""
    book_isbns.concat book.each{|b| b.isbn} if book && book.lenth > 0
    books =  Book.where(:author => /#{Regexp.escape(params[:author])}/).all if params[:author] != ""
    book_isbns.concat  book.each{|b| b.isbn} if books && books.lenth > 0
    #binding.pry
    @posts = []
    book_isbns.each do |isbn|
      book = Book.where(:isbn => isbn).all.first
      posts = Post.where(:book_id => book._id).all
      @posts.concat posts if posts.length > 0
    end
    @authors = []
    @posts.each do |post|
      authors = Author.where(:book_id => post.book_id).fields(:name).all
      @authors << authors.map(&:name)
    end

    redirect '/not_found' unless @posts.length > 0
    erb :"/buying/results"
  end

  get '/selling' do
    erb :"selling/index"
  end

  post '/selling' do
    #binding.pry
    form do
      field :isbn, :present => true, :length => 10..16
      field :price, :present => true, :int => {:gte => 0}
      #field :title
      #field :author
      field :condition, :present => true, :regexp => %r{^.*(perfect|good|fair|poor|very poor).*$}
    end

    if form.failed?
      output = erb :"selling/index"
      fill_in_form(output)
    else
      book_for_sale = find_book_for_sale(params)
    end
  end

  get '/offer/make/:post_id' do
    erb :"buying/offer"
  end

  get '/offer/make/asking/:post_id' do
    #Email post.seller@students.wwu.edu with the offer
    #Create Offer in DB -- buyer is cas user, seller is post.seller
    post = Post.find(params[:post_id])
    offer = Offer.new({
                    :seller => post.seller,
                    :buyer => @user,
                    :price => post.price,
                    :post_id => post._id
                    })
    post.offers << offer
    post.save!
    redirect '/offer/success'
  end

  get '/offer/success' do
    erb :"buying/success"
  end
  get '/offer/:post_id' do
    @post = Post.find(params[:post_id])
    @book = Book.find(@post.book_id)
    authors = Author.where(:book_id => session[:book_id]).all
    @authors = authors.map(&:name)
    erb :"buying/offer"
  end

  get '/selling/confirm' do
    @condition = session[:condition]
    @price = session[:price]
    @book = Book.find(session[:book_id])
    @authors = Author.where(:book_id => session[:book_id]).all

    erb :"selling/confirm"
  end

  get '/selling/sell' do
    book = Book.find(session[:book_id])
    post = Post.new(
                   :book => book,
                   :seller => @user,
                   :price => session[:price],
                   :condition => session[:condition]
                   )
    book.reload
    post.save!
    book.reload
    redirect '/selling/success'
  end

  get '/selling/success' do
    erb :"selling/success"
  end

  get '/not_found' do
    erb :not_found
  end

  get '/offers' do
    @posts = Post.where(:seller => @user).all
    erb :"offers/index"
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
