require 'rubygems'
require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'sinatra/formkeeper'
require 'mongo_mapper'
require 'lisbn'
require 'chronic'
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
    book_for_sale = validate_sale
    if !book_for_sale.nil? then
      confirm_post(book_for_sale._id, params[:price], params[:condition], true)
    else
      authors = [] << params[:author]
      unverified_book = Book.create({
          :title => params[:title],
          :isbn => params[:isbn],
          :authors => authors.map{|a| Author.new(:name => a)}
      })
      confirm_post(unverified_book._id, params[:price], params[:condition], false)
    end
    binding.pry
    redirect '/selling/confirm'
  end

  get '/selling/confirm' do
    @condition = session[:condition]
    @price = session[:price]
    @book = Book.find(session[:book_id])
    @authors = Author.where(:book_id => session[:book_id]).all
    @verified = session[:verified]
    erb :"selling/confirm"
  end

  get '/selling/sell' do
    book = Book.find(session[:book_id])
    post = Post.new(
                   :book => book,
                   :seller => @user,
                   :price => session[:price],
                   :condition => session[:condition],
                   :verified_book => session[:verified]
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

  get '/sales' do
    @posts = Post.where(:seller => @user).all
    meetings = Meeting.where(:seller => @user).all
    @meetings = meetings.select{|m| Chronic.parse(m.date) > Date.today-5}
    @messages = []
    @meetings.each do |m|
      @messages << "Accepted" if m.accepted
      @messages << "Declined" if !m.accepted && m.declined
      @messages << "Pending" if !m.accepted && !m.declined
    end
    @books = @meetings.map{Book.find(&:book_id)}
    erb :"sales/index"
  end

  get '/sales/sell/:offer_id' do
    #TODO: Email buyer
    offer = Offer.find(params[:offer_id])
    offer.set(active => false)
    offer.set(accepted => true)
    offer.reload
    offer.save
    erb :"sales/success"
  end

  post '/meeting/create/:offer_id' do
    @offer = Offer.find(params[:offer_id])
    @post = Post.find(@offer.post_id)
    @book = Book.find(@post.book_id)
    authors = Author.where(:book_id => @book._id).all
    @authors = authors.map(&:name)
    #Validate form
    form do
      field :location, :present => true
      field :datepicker, :present => true, :regexp => %r{^\d{2}\/\d{2}\/\d{4}$}
      field :timepicker, :present => true
    end

    if form.failed?
      output = erb :"offers/accept"
      fill_in_form(output)
    else
      #create meeting
      meeting = Meeting.create({
          :seller => @offer.seller,
          :buyer => @offer.buyer,
          :accepted => false,
          :declined => false,
          :book_id => @book._id,
          :offer_id => @offer._id,
          :location => params[:location],
          :date => params[:datepicker],
          :time => params[:timepicker]
        })
        meeting.save!


      #TODO:Email both parties
      #await response
      erb :"meeting/sent"
    end
  end

  get '/meeting/create/error' do
    erb :"meeting/error"
  end

  get '/meeting/accept/:meeting_id' do
    #Email both parties
    meeting = Meeting.find(params[:meeting_id])
    meeting.accepted = true
    meeting.save!
    redirect '/sales'
  end

  get '/meeting/decline/:meeting_id' do
    meeting = Meeting.find(params[:meeting_id])
    meeting.accepted = false
    meeting.declined = true
    meeting.save!
    redirect '/sales'
  end

  get '/offers' do
    @posts = Post.where(:seller => @user).all
    meetings = Meeting.where(:seller => @user).all
    @meetings = meetings.select{|m| Chronic.parse(m.date) > Date.today-5}
    @messages = []
    @meetings.each do |m|
      @messages << "Accepted" if m.accepted
      @messages << "Declined" if !m.accepted && m.declined
      @messages << "Pending" if !m.accepted && !m.declined
    end
    @books = @meetings.map{Book.find(&:book_id)}
    @active_offers = Offer.where(:buyer => @user, :active => true, :accepted => false).all
    @declined_offers = Offer.where(:buyer => @user, :active => false, :accepted => false).all
    @accepted_offers = Offer.where(:buyer => @user, :active => false, :accepted => true).all
    erb :"offers/index"
  end

  get '/offer/make/:post_id' do
    erb :"buying/offer"
  end

  get '/offer/make/asking/:post_id' do
    #TODO:Email post.seller@students.wwu.edu with the offer
    post = Post.find(params[:post_id])
    offer = Offer.create({
                    :seller => post.seller,
                    :buyer => @user,
                    :price => post.price,
                    :active => true,
                    :accepted => false,
                    :post_id => post._id
                    })

    offer.save!
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

  get '/offer/decline/:offer_id' do
    #TODO:Email buy that their offer was declined
    offer = Offer.find(params[:offer_id])
    offer.set(:active => false)
    offer.set(:accepted => false)
    offer.reload
    offer.save!
    redirect '/sales'
  end

  get '/offer/accept/:offer_id' do
    @offer = Offer.find(params[:offer_id])
    @post = Post.find(@offer.post_id)
    @book = Book.find(@post.book_id)
    authors = Author.where(:book_id => @book._id).all
    @authors = authors.map(&:name)
    erb :"offers/accept"
  end

end
