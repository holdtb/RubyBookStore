module BookstoreHelper

  def get_new_posts
    Post.sort(:created_at.desc).limit(5).all
  end

  def get_authors(posts)
    authors = []
    posts.each do |post|
      authors_found = Author.where(:book_id => post.book_id).fields(:name).all
      authors << authors_found.map(&:name)
    end
    authors
  end

  def get_posts(isbns)
    posts = []
    isbns.each do |isbn|
      book = Book.where(:isbn => isbn).all.first
      posts_found = Post.where(:book_id => book._id).all
      posts.concat posts_found if posts_found.length > 0
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

    book = Book.where(:title => /#{Regexp.escape(params[:title])}/i).all if params[:title] != ""
    book_isbns.concat book.map(&:isbn) if book && book.length > 0
    book_isbns
  end


  def validate_sale
    form do
      field :isbn, :present => true, :length => 10..16
      field :price, :present => true, :int => {:gte => 0}
      field :condition, :present => true, :regexp => %r{^.*(perfect|good|fair|poor|very poor).*$}
    end

    if form.failed?
      output = erb :"selling/index"
      fill_in_form(output)
    else
      book_for_sale = find_book_for_sale(params)
    end
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
