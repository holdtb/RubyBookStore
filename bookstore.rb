require 'rubygems'
require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'sinatra/formkeeper'
require 'data_mapper'
require 'dm-sqlite-adapter'
require 'sqlite3'
require 'lisbn'
require 'chronic'
Dir.glob('lib/**/*.rb') { |f| require_relative f }
Dir["./model/*.rb"].each {|file| require file }
DataMapper.setup :default, "sqlite3://#{Dir.pwd}/database.db"

class Bookstore < Sinatra::Base
  helpers Sinatra::ContentFor
  register Sinatra::Reloader
  register Sinatra::FormKeeper
  use Rack::Session::Cookie, :secret => 'bookstore'
  helpers GoogleBookScraper
  helpers CasHelpers
  helpers BookstoreHelper

  DataMapper.finalize.auto_upgrade!

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

    if book_for_sale.class == Array then
      return book_for_sale.first
    elsif !book_for_sale.nil? then
      confirm_post(book_for_sale.id, params[:price], params[:condition], true)
    else
      authors = [] << params[:author]
      unverified_book = Book.create(
          :title => params[:title],
          :isbn => params[:isbn],
          :authors => authors.map{|a| Author.create(:name => a)}
      )

      confirm_post(unverified_book.id, params[:price], params[:condition], false)
    end
    redirect '/selling/confirm'
  end

  get '/selling/confirm' do
    @condition = session[:condition]
    @price = session[:price]
    @book = Book.get(session[:book_id])
    @authors = Author.all(:book_id => session[:book_id])
    @verified = session[:verified]
    erb :"selling/confirm"
  end

  get '/selling/sell' do
    create_post(session[:book_id])
    redirect '/selling/success'
  end

  get '/selling/success' do
    erb :"selling/success"
  end

  get '/not_found' do
    erb :not_found
  end

  get '/sales' do
    meetings = Meeting.all(:seller => @user)
    @meetings = meetings.select{|m| Chronic.parse(m.date) > Date.today-5}
    @messages = []
    @meetings.each do |m|
      @messages << "Accepted" if m.accepted
      @messages << "Declined" if !m.accepted && m.declined
      @messages << "Pending" if !m.accepted && !m.declined
    end
    @posts = Post.all(:seller => @user)

    # Remove posts that have meetings that are accepted
    @meetings.each do |m|
      @posts.each do |p|
        p.offers.each do |po|
          @posts.delete_if{po.id == m.id and m.declined == false}
        end
      end
    end

    @books = @meetings.map{|m| Book.get(m.book_id)}

    erb :"sales/index"
  end

  get '/sales/sell/:offer_id' do
    sell(params[:offer_id])
    erb :"sales/success"
  end

  post '/meeting/create/:offer_id' do
    @offer = Offer.get(params[:offer_id])
    @post = Post.get(@offer.post_id)
    @book = Book.get(@post.book_id)
    authors = Author.all(:book_id => @book.id)
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
      create_meeting(@offer, @book, params)
      erb :"meeting/sent"
    end
  end

  get '/meeting/create/error' do
    erb :"meeting/error"
  end

  get '/meeting/accept/:meeting_id' do
    accept_meeting(params[:meeting_id])
    redirect '/sales'
  end

  get '/meeting/decline/:meeting_id' do
    decline_meeting(params[:meeting_id])
    redirect '/sales'
  end

  get '/offer/success' do
    erb :"buying/success"
  end

  get '/offers' do
    meetings = Meeting.all(:seller => @user)
    @meetings = meetings.select{|m| Chronic.parse(m.date) > Date.today-5}
    @messages = []
    @meetings.each do |m|
      @messages << "Accepted" if m.accepted
      @messages << "Declined" if !m.accepted && m.declined
      @messages << "Pending" if !m.accepted && !m.declined
    end

    @books = @meetings.map{|m| Book.get(m.book_id)}
    @active_offers = Offer.all(:buyer => @user, :active => true, :accepted => false)

    @active_offers.each do |ao|
      @meetings.each do |m|
        @active_offers.delete_if{m.offer_id == ao.id}
      end
    end

    @declined_offers = Offer.all(:buyer => @user, :active => false, :accepted => false, :archive => false)
    @accepted_offers = Offer.all(:buyer => @user, :active => false, :accepted => true, :archive => false)
    erb :"offers/index"
  end

  get '/offer/:post_id' do
    view_post(params[:post_id])
    erb :"buying/offer"
  end

  get '/offer/make/asking/:post_id' do
    create_offer_asking_price(params[:post_id])
    redirect '/offer/success'
  end

  get '/offer/make/:post_id' do
    erb :"buying/offer"
  end

  get '/offer/decline/:offer_id' do
    decline_offer(params[:offer_id])
    redirect '/sales'
  end

  get '/offer/accept/:offer_id' do
    accept_offer(params)
    erb :"offers/accept"
  end

end
