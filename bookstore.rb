require 'rubygems'
require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'sinatra/formkeeper'
require 'mongo_mapper'
require 'lisbn'
Dir.glob('lib/**/*.rb') { |f| require_relative f }
Dir["./model/*.rb"].each {|file| require file }

class Bookstore < Sinatra::Base
  set :public_folder, 'public'
  helpers Sinatra::ContentFor
  register Sinatra::Reloader
  register Sinatra::FormKeeper
  use Rack::Session::Cookie, :secret => 'bookstore'
  helpers GoogleBookScraper
  helpers CasHelpers
  helpers BookstoreHelper

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
    @recent_posts = get_new_posts
    @authors = get_authors(@recent_posts)
    erb :"buying/index"
  end

  post '/buying' do
    book_isbns = get_book_isbns(params)
    @posts = get_posts(book_isbns)
    @authors = get_authors(@posts)
    redirect '/not_found' unless @posts.length > 0
    erb :"/buying/results"
  end

  get '/selling' do
    erb :"selling/index"
  end

  post '/selling' do
    validate_sale
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

  get '/offer/make/:post_id' do
    erb :"buying/offer"
  end

  get '/offer/make/asking/:post_id' do
    #TODO:Email post.seller@students.wwu.edu with the offer
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

  get '/offer/decline/:post_id' do
    Offer.destroy(params[:post_id])
    #TODO:Email buy that their offer was declined
    redirect '/offers'
  end

  get '/offer/accept/:post_id' do
    #TODO:Implement this
  end

end
