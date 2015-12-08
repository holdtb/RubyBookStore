require 'pry'
require 'obscenity'
module BookstoreHelper

  def get_new_posts
    #Post.sort(:created_at.desc).limit(4).all
    Post.all(:limit => 4, :order => [:created_at.desc])
  end

  def get_authors(posts)
    authors = []
    posts.each do |post|
      #authors_found = Author.where(:book_id => post.book_id).fields(:name).all
      authors_found = Author.all(:book_id => post.book_id)
      authors << authors_found.map(&:name)
    end
    authors
  end

  def get_posts(isbns)
    posts = []
    isbns.each do |isbn|
      #book = Book.where(:isbn => isbn).all
      book = Book.all(:isbn => isbn)
      if !book.nil?
        book = book.first
      end

      posts_found = Post.all(:book_id => book.id) if !book.nil?
      posts.concat posts_found if !posts_found.nil? && posts_found.length > 0
    end
    posts
  end

  def get_book_isbns(params)
    book_isbns = []
    if params[:isbn] != "" then
      stripped_isbn = params[:isbn].gsub('-','').strip
      lisbn = Lisbn.new(stripped_isbn)
      isbn = lisbn.isbn13.to_s if lisbn.valid?
      book_isbns << isbn if isbn
    end

    book = Book.all(:title.like => params[:title]+"%") if params[:title] != ""
    book_isbns.concat book.map(&:isbn) if book && book.length > 0
    book_isbns
  end


  def validate_sale
    form do
      field :isbn, :present => true, :regexp => %r{((978[\--– ])?[0-9][0-9\--– ]{10}[\--– ][0-9xX])|((978)?[0-9]{9}[0-9Xx])}
      field :price, :present => true, :int => {:gte => 0}
      field :title, :present => true, :length => 1..80
      field :author, :present => true, :length => 1..80
      field :condition, :present => true, :regexp => %r{^.*(perfect|good|fair|poor|very poor).*$}
    end

    if form.failed?
      output = erb :"selling/index"
      result = fill_in_form(output)
      return [result]
    else
      book_for_sale = find_book_for_sale(params)
    end
  end

  def find_book_for_sale(params)
    if(params[:isbn] != "") then
      stripped_isbn = params[:isbn].gsub('-','').strip
      isbn = Lisbn.new(stripped_isbn)
      book = scrape_and_find(isbn)
      return book unless book.nil?
    end
    return nil
  end

  def confirm_post(book_id, price, condition, verified)
    require_authorization(request, session) unless logged_in?(request, session)
    @user = session[:cas_user]
    session[:condition] = condition
    session[:price] = price
    session[:book_id] = book_id
    session[:verified] = verified
  end

  # def cleanse(book)
  #   authors = Author.all(:book_id => book.id)
  # 
  #   # authors.each do |a|
  #   #   new_author = Obscenity.replacement(:stars).sanitize(a.name)
  #   #   a.name = new_author
  #   #   result = a.save
  #   #   binding.pry
  #   # end
  #   author = authors[0]
  #   author.name = Obscenity.replacement(:stars).sanitize(author.name)
  #   result = author.save
  #   binding.pry
  #
  #   new_title = Obscenity.replacement(:stars).sanitize(book.title)
  #   book.title = new_title
  #   result = book.save
  #   binding.pry
  #   book
  # end

####SELLING#####

  def create_post(book_id) #/selling/SELLING
    book = Book.get(book_id)
    post = Post.create(
                   :book_id => book.id,
                   :seller => @user,
                   :price => session[:price],
                   :condition => session[:condition],
                   :verified_book => session[:verified]
                   )
  end


  ####################Offer#############################

  def view_post(post_id) #/offer/:post_id
    @post = Post.get(post_id)
    @book = Book.get(@post.book_id)
    authors = Author.all(:book_id => @book.id)
    @authors = authors.map(&:name)
    @authors = "Unable to find authors for this book." unless @authors.length > 0
  end

  def create_offer_asking_price(post_id) #/offer/make/asking/:post_id
    #TODO:Email post.seller@students.wwu.edu with the offer
    post = Post.get(post_id)
    offer = Offer.create(
                    :seller => post.seller,
                    :buyer => @user,
                    :price => post.price,
                    :active => true,
                    :accepted => false,
                    :post_id => post.id
                    )

    offer.save
    post.offers << offer
    post.save
  end

  def decline_offer(offer_id) #/offer/decline/:offer_id
    #TODO:Email buy that their offer was declined

    offer = Offer.get(offer_id)
    offer.active = false
    offer.accepted = false
    offer.save
    post = Post.get(offer.post_id)
    post.offers.delete(offer)
    post.offers.save
  end

  def accept_offer(params) #/offer/accept/:offer_id
    @offer = Offer.get(params[:offer_id])
    @post = Post.get(@offer.post_id)
    @book = Book.get(@post.book_id)
    authors = Author.all(:book_id => @book.id)
    @authors = authors.map(&:name)
  end

  #####################################################

  ##################Meetings############################

  def decline_meeting(meeting_id)
    #TODO:Email both parties
    meeting = Meeting.get(meeting_id)
    meeting.accepted = false
    meeting.declined = true
    meeting.save
  end

  def accept_meeting(meeting_id)
    #TODO:Email both parties
    meeting = Meeting.get(meeting_id)
    meeting.accepted = true
    meeting.save

    #Remove the old post
    m_offer = meeting.offer
    m_offer.active = false
    m_offer.accepted = true
    m_offer.archive = true
    m_offer.save
    post = Post.get(m_offer.post_id)
    post.offers = []
    result = post.destroy
  end

  def create_meeting(offer, book, params)
    meeting = Meeting.create(
        :seller => offer.seller,
        :buyer => offer.buyer,
        :accepted => false,
        :declined => false,
        :book_id => book.id,
        :offer_id => offer.id,
        :location => params[:location],
        :date => params[:datepicker],
        :time => params[:timepicker]
      )
      meeting.offer = offer
      meeting.save

    #TODO:Email both parties
  end
  #######################################################


#################SALES#######################

def sell(offer_id)
  #TODO: Email buyer
  offer = Offer.get(params[:offer_id])
  offer.update(:active => false)
  offer.update(:accepted => true)
end

#######

end
