module Wgit
  # DSL methods that act as a wrapper around Wgit's underlying class methods.
  # All instance vars/constants are prefixed to avoid conflicts when included.
  module DSL
    # Error message shown when there's no URL to crawl.
    DSL_ERROR__NO_START_URL = "missing url, pass as parameter to this or \
the 'start' function".freeze

    ### CRAWLER METHODS ###

    # Defines an extractor using `Wgit::Document.define_extractor` underneath.
    #
    # @param var [Symbol] The name of the variable to be initialised, that will
    #   contain the extracted content.
    # @param xpath [String, #call] The xpath used to find the element(s)
    #   of the webpage. Only used when initializing from HTML.
    #
    #   Pass a callable object (proc etc.) if you want the
    #   xpath value to be derived on Document initialisation (instead of when
    #   the extractor is defined). The call method must return a valid xpath
    #   String.
    # @param opts [Hash] The options to define an extractor with. The
    #   options are only used when intializing from HTML, not the database.
    # @option opts [Boolean] :singleton The singleton option determines
    #   whether or not the result(s) should be in an Array. If multiple
    #   results are found and singleton is true then the first result will be
    #   used. Defaults to true.
    # @option opts [Boolean] :text_content_only The text_content_only option
    #   if true will use the text content of the Nokogiri result object,
    #   otherwise the Nokogiri object itself is returned. Defaults to true.
    # @yield The block is executed when a Wgit::Document is initialized,
    #   regardless of the source. Use it (optionally) to process the result
    #   value.
    # @yieldparam value [Object] The result value to be assigned to the new
    #   `var`.
    # @yieldparam source [Wgit::Document, Object] The source of the `value`.
    # @yieldparam type [Symbol] The `source` type, either `:document` or (DB)
    #   `:object`.
    # @yieldreturn [Object] The return value of the block becomes the new var's
    #   value. Return the block's value param unchanged if you want to inspect.
    # @raise [StandardError] If the var param isn't valid.
    # @return [Symbol] The given var Symbol if successful.
    def extract(var, xpath, opts = {}, &block)
      Wgit::Document.define_extractor(var, xpath, opts, &block)
    end

    # Sets and returns the Wgit::Crawler used in subsequent crawls including
    # indexing. Defaults to `Wgit::Crawler.new` if not given a param. See the
    # Wgit::Crawler documentation for more details.
    #
    # @yield [crawler] Given the DSL crawler; use the block to configure.
    # @return [Wgit::Crawler] The crawler instance used by the DSL.
    def use_crawler(crawler = nil)
      @dsl_crawler = crawler || @dsl_crawler || Wgit::Crawler.new
      yield @dsl_crawler if block_given?
      @dsl_crawler
    end

    # Sets the URL to be crawled when a `crawl*` or `index*` method is
    # subsequently called. Calling this is optional as the URL can be
    # passed to the method instead. You can also omit the url param and just
    # use the block to configure the crawler instead.
    #
    # @param urls [*String, *Wgit::Url] The URL(s) to crawl
    #   or nil (if only using the block to configure the crawler).
    # @yield [crawler] The crawler that'll be used in the subsequent
    #   crawl/index; use the block to configure.
    def start(*urls, &block)
      use_crawler(&block) if block_given?
      @dsl_start = urls
    end

    # Sets the xpath to be followed when `crawl_site` or `index_site` is
    # subsequently called. Calling this method is optional as the default is to
    # follow all `<a>` href's that point to the site domain. You can also pass
    # `follow:` to the crawl/index methods directly.
    #
    # @param xpath [String] The xpath which is followed when crawling/indexing
    #   a site. Use `:default` to restore the default follow logic.
    def follow(xpath)
      @dsl_follow = xpath
    end

    # Crawls one or more individual urls using `Wgit::Crawler#crawl_url`
    # underneath. If no urls are provided, then the `start` URL is used.
    #
    # @param urls [*Wgit::Url] The URL's to crawl. Defaults to the `start`
    #   URL(s).
    # @param follow_redirects [Boolean, Symbol] Whether or not to follow
    #   redirects. Pass a Symbol to limit where the redirect is allowed to go
    #   e.g. :host only allows redirects within the same host. Choose from
    #   :origin, :host, :domain or :brand. See Wgit::Url#relative? opts param.
    #   This value will be used for all urls crawled.
    # @yield [doc] Given each crawled page (Wgit::Document); this is the only
    #   way to interact with them.
    # @raise [StandardError] If no urls are provided and no `start` URL has
    #   been set.
    # @return [Wgit::Document] The last Document crawled.
    def crawl(*urls, follow_redirects: true, &block)
      urls = (@dsl_start || []) if urls.empty?
      raise DSL_ERROR__NO_START_URL if urls.empty?

      urls.map! { |url| Wgit::Url.parse(url) }
      get_crawler.crawl_urls(*urls, follow_redirects:, &block)
    end

    # Crawls an entire site using `Wgit::Crawler#crawl_site` underneath. If no
    # url is provided, then the first `start` URL is used.
    #
    # @param urls [*String, *Wgit::Url] The base URL(s) of the website(s) to be
    #   crawled. It is recommended that this URL be the index page of the site
    #   to give a greater chance of finding all pages within that site/host.
    #   Defaults to the `start` URLs.
    # @param follow [String] The xpath extracting links to be followed during
    #   the crawl. This changes how a site is crawled. Only links pointing to
    #   the site domain are allowed. The `:default` is any `<a>` href returning
    #   HTML. This can also be set using `follow`.
    # @param allow_paths [String, Array<String>] Filters the `follow:` links by
    #   selecting them if their path `File.fnmatch?` one of allow_paths.
    # @param disallow_paths [String, Array<String>] Filters the `follow` links
    #   by rejecting them if their path `File.fnmatch?` one of disallow_paths.
    # @yield [doc] Given each crawled page (Wgit::Document) of the site.
    #   A block is the only way to interact with each crawled Document.
    #   Use `doc.empty?` to determine if the page is valid.
    # @raise [StandardError] If no url is provided and no `start` URL has been
    #   set.
    # @return [Array<Wgit::Url>, nil] Unique Array of external urls collected
    #   from all of the site's pages or nil if the given url could not be
    #   crawled successfully.
    def crawl_site(
      *urls, follow: @dsl_follow,
      allow_paths: nil, disallow_paths: nil, &block
    )
      urls = (@dsl_start || []) if urls.empty?
      raise DSL_ERROR__NO_START_URL if urls.empty?

      xpath = follow || :default
      opts  = { follow: xpath, allow_paths:, disallow_paths: }

      urls.reduce([]) do |externals, url|
        externals + get_crawler.crawl_site(Wgit::Url.parse(url), **opts, &block)
      end
    end

    # Returns the DSL's `Wgit::Crawler#last_response`.
    #
    # @return [Wgit::Response] The response from the last URL crawled.
    def last_response
      get_crawler.last_response
    end

    # Nilifies the DSL instance variables.
    def reset
      @dsl_crawler = nil
      @dsl_start   = nil
      @dsl_follow  = nil
      @dsl_db      = nil
    end

    ### INDEXER METHODS ###

    # Defines the connected database instance used in subsequent index and DB
    # method calls. This method is optional however, as a new instance of the
    # Wgit::Database.adapter_class will be initialised otherwise. Therefore
    # if not calling this method, you should ensure
    # ENV['WGIT_CONNECTION_STRING'] is set or the connection will fail.
    #
    # @param db [Wgit::Database::DatabaseAdapter] The connected database
    #   instance used in subsequent `index*` method calls.
    def use_database(db)
      @dsl_db = db
    end

    # Indexes the World Wide Web using `Wgit::Indexer#index_www` underneath.
    #
    # @param max_sites [Integer] The number of separate and whole
    #   websites to be crawled before the method exits. Defaults to -1 which
    #   means the crawl will occur until manually stopped (Ctrl+C etc).
    # @param max_data [Integer] The maximum amount of bytes that will be
    #   scraped from the web (default is 1GB). Note, that this value is used to
    #   determine when to stop crawling; it's not a guarantee of the max data
    #   that will be obtained.
    def index_www(max_sites: -1, max_data: 1_048_576_000)
      indexer = Wgit::Indexer.new(get_db, get_crawler)

      indexer.index_www(max_sites:, max_data:)
    end

    # Indexes a single website using `Wgit::Indexer#index_site` underneath.
    #
    # @param urls [*String, *Wgit::Url] The base URL(s) of the website(s) to
    #   crawl. Can be set using `start`.
    # @param insert_externals [Boolean] Whether or not to insert the website's
    #   external URL's into the database.
    # @param follow [String] The xpath extracting links to be followed during
    #   the crawl. This changes how a site is crawled. Only links pointing to
    #   the site domain are allowed. The `:default` is any `<a>` href returning
    #   HTML. This can also be set using `follow`.
    # @param allow_paths [String, Array<String>] Filters the `follow:` links by
    #   selecting them if their path `File.fnmatch?` one of allow_paths.
    # @param disallow_paths [String, Array<String>] Filters the `follow` links
    #   by rejecting them if their path `File.fnmatch?` one of disallow_paths.
    # @yield [doc] Given the Wgit::Document of each crawled webpage, before it
    #   is inserted into the database allowing for prior manipulation.
    # @raise [StandardError] If no url is provided and no `start` URL has been
    #   set.
    # @return [Integer] The total number of pages crawled within the website.
    def index_site(
      *urls, insert_externals: false, follow: @dsl_follow,
      allow_paths: nil, disallow_paths: nil, &block
    )
      urls = (@dsl_start || []) if urls.empty?
      raise DSL_ERROR__NO_START_URL if urls.empty?

      indexer    = Wgit::Indexer.new(get_db, get_crawler)
      xpath      = follow || :default
      crawl_opts = {
        insert_externals:, follow: xpath, allow_paths:, disallow_paths:
      }

      urls.reduce(0) do |total, url|
        total + indexer.index_site(Wgit::Url.parse(url), **crawl_opts, &block)
      end
    end

    # Indexes a single webpage using `Wgit::Indexer#index_url` underneath.
    #
    # @param urls [*Wgit::Url] The webpage URL's to crawl. Defaults to the
    #   `start` URL(s).
    # @param insert_externals [Boolean] Whether or not to insert the website's
    #   external URL's into the database.
    # @yield [doc] Given the Wgit::Document of the crawled webpage,
    #   before it's inserted into the database allowing for prior
    #   manipulation. Return nil or false from the block to prevent the
    #   document from being saved into the database.
    # @raise [StandardError] If no urls are provided and no `start` URL has
    #   been set.
    def index(*urls, insert_externals: false, &block)
      urls = (@dsl_start || []) if urls.empty?
      raise DSL_ERROR__NO_START_URL if urls.empty?

      indexer = Wgit::Indexer.new(get_db, get_crawler)

      urls.map! { |url| Wgit::Url.parse(url) }
      indexer.index_urls(*urls, insert_externals:, &block)
    end

    ### DATABASE METHODS ###

    # Performs a search of the database's indexed documents and pretty prints
    # the results in a search engine-esque format. See
    # `Wgit::Database::DatabaseAdapter#search` and `Wgit::Document#search!`
    # for details of how the search methods work.
    #
    # @param query [String] The text query to search with.
    # @param stream [nil, #puts] Any object that respond_to?(:puts). It is used
    #   to output text somewhere e.g. a file or STDERR. Use nil for no output.
    # @param case_sensitive [Boolean] Whether character case must match.
    # @param whole_sentence [Boolean] Whether multiple words should be searched
    #   for separately.
    # @param limit [Integer] The max number of results to print.
    # @param skip [Integer] The number of DB records to skip.
    # @param sentence_limit [Integer] The max length of each result's text
    #   snippet.
    # @yield [doc] Given each search result (Wgit::Document) returned from the
    #   database containing only its matching `#text`.
    # @return [Array<Wgit::Document>] The search results with matching text.
    def search(
      query, stream: $stdout,
      top_result_only: true, include_score: false,
      case_sensitive: false, whole_sentence: true,
      limit: 10, skip: 0, sentence_limit: 80
    )
      stream ||= File.open(File::NULL, 'w')

      results = get_db.search(
        query, case_sensitive:, whole_sentence:, limit:, skip:)

      results.each do |doc|
        doc.search_text!(
          query, case_sensitive:, whole_sentence:, sentence_limit:)
        yield(doc) if block_given?
      end

      if top_result_only
        Wgit::Utils.pprint_top_search_results(results, include_score:, stream:)
      else
        Wgit::Utils.pprint_all_search_results(results, include_score:, stream:)
      end

      results
    end

    # Deletes everything in the urls and documents collections by calling
    # `Wgit::Database::DatabaseAdapter#empty` underneath.
    #
    # @return [Integer] The number of deleted records.
    def empty_db!
      get_db.empty
    end

    private

    def get_crawler
      @dsl_crawler ||= Wgit::Crawler.new
    end

    def get_db
      @dsl_db ||= Wgit::Database.new
    end

    alias_method :crawl_url,  :crawl
    alias_method :crawl_r,    :crawl_site
    alias_method :index_r,    :index_site
    alias_method :index_url,  :index
    alias_method :start_urls, :start
  end
end
