module Wgit
  # DSL methods that act as a wrapper around Wgit's underlying class methods.
  # All instance vars/constants are prefixed to avoid conflicts when included.
  module DSL
    DSL_ERROR__NO_START_URL = "missing url, pass as parameter to this or \
the 'start' function"

    ### CRAWLER METHODS ###

    def extract(var, xpath, opts = {}, &block)
      Wgit::Document.define_extension(var, xpath, opts, &block)
    end

    def crawler
      @dsl_crawler ||= Wgit::Crawler.new
      yield @dsl_crawler if block_given?
      @dsl_crawler
    end

    def start(url = nil, &block)
      crawler(&block)
      @dsl_start = url if url
    end

    def follow(xpath)
      @dsl_follow = xpath
    end

    def crawl(*urls, follow_redirects: true, &block)
      urls << @dsl_start if urls.empty?
      raise DSL_ERROR__NO_START_URL if urls.compact.empty?

      urls.map! { |url| Wgit::Url.parse(url) }
      crawler.crawl_urls(*urls, follow_redirects: follow_redirects, &block)
    end

    def crawl_site(
      url = @dsl_start, follow: @dsl_follow,
      allow_paths: nil, disallow_paths: nil, &block
    )
      raise DSL_ERROR__NO_START_URL unless url

      xpath = follow || :default
      opts  = {
        follow: xpath, allow_paths: allow_paths, disallow_paths: disallow_paths
      }

      crawler.crawl_site(Wgit::Url.parse(url), opts, &block)
    end

    def last_response
      crawler.last_response
    end

    ### INDEXER METHODS ###

    def connection_string(conn_str)
      @dsl_conn_str = conn_str
    end

    # Convenience method to index the World Wide Web using
    # Wgit::Indexer#index_www.
    #
    # Retrieves uncrawled url's from the database and recursively crawls each
    # site storing their internal pages into the database and adding their
    # external url's to be crawled later on. Logs info on the crawl
    # using Wgit.logger as it goes along.
    #
    # @param connection_string [String] The database connection string. Set as
    #   nil to use ENV['WGIT_CONNECTION_STRING'].
    # @param max_sites [Integer] The number of separate and whole
    #   websites to be crawled before the method exits. Defaults to -1 which
    #   means the crawl will occur until manually stopped (Ctrl+C etc).
    # @param max_data [Integer] The maximum amount of bytes that will be
    #   scraped from the web (default is 1GB). Note, that this value is used to
    #   determine when to stop crawling; it's not a guarantee of the max data
    #   that will be obtained.
    def index_www(
      connection_string: @dsl_conn_str, max_sites: -1, max_data: 1_048_576_000
    )
      db      = Wgit::Database.new(connection_string)
      indexer = Wgit::Indexer.new(db, crawler)

      indexer.index_www(max_sites: max_sites, max_data: max_data)
    end

    # Convenience method to index a single website using
    # Wgit::Indexer#index_site.
    #
    # Crawls a single website's pages and stores them into the database.
    # There is no max download limit so be careful which sites you index.
    #
    # @param url [Wgit::Url, String] The base Url of the website to crawl.
    # @param connection_string [String] The database connection string. Set as
    #   nil to use ENV['WGIT_CONNECTION_STRING'].
    # @param insert_externals [Boolean] Whether or not to insert the website's
    #   external Url's into the database.
    # @param allow_paths [String, Array<String>] Filters links by selecting
    #   them if their path `File.fnmatch?` one of allow_paths.
    # @param disallow_paths [String, Array<String>] Filters links by rejecting
    #   them if their path `File.fnmatch?` one of disallow_paths.
    # @yield [doc] Given the Wgit::Document of each crawled webpage, before it
    #   is inserted into the database allowing for prior manipulation.
    # @return [Integer] The total number of pages crawled within the website.
    def index_site(
      url = @dsl_start, connection_string: @dsl_conn_str,
      insert_externals: true, follow: @dsl_follow,
      allow_paths: nil, disallow_paths: nil, &block
    )
      raise DSL_ERROR__NO_START_URL unless url

      url        = Wgit::Url.parse(url)
      db         = Wgit::Database.new(connection_string)
      indexer    = Wgit::Indexer.new(db, crawler)
      xpath      = follow || :default
      crawl_opts = {
        insert_externals: insert_externals, follow: xpath,
        allow_paths: allow_paths, disallow_paths: disallow_paths
      }

      indexer.index_site(url, crawl_opts, &block)
    end

    # Convenience method to index a single webpage using
    # Wgit::Indexer#index_url.
    #
    # Crawls a single webpage and stores it into the database.
    # There is no max download limit so be careful of large pages.
    #
    # @param url [Wgit::Url, String] The Url of the webpage to crawl.
    # @param connection_string [String] The database connection string. Set as
    #   nil to use ENV['WGIT_CONNECTION_STRING'].
    # @param insert_externals [Boolean] Whether or not to insert the website's
    #   external Url's into the database.
    # @yield [doc] Given the Wgit::Document of the crawled webpage, before it's
    #   inserted into the database allowing for prior manipulation.
    def index(
      *urls, connection_string: @dsl_conn_str,
      insert_externals: true, &block
    )
      urls << @dsl_start if urls.empty?
      raise DSL_ERROR__NO_START_URL if urls.compact.empty?

      db      = Wgit::Database.new(connection_string)
      indexer = Wgit::Indexer.new(db, crawler)

      urls.map! { |url| Wgit::Url.parse(url) }
      indexer.index_urls(*urls, insert_externals: insert_externals, &block)
    end

    # Performs a search of the database's indexed documents and pretty prints
    # the results. See Wgit::Database#search and Wgit::Document#search for
    # details of how the search works.
    #
    # @param query [String] The text query to search with.
    # @param connection_string [String] The database connection string. Set as
    #   nil to use ENV['WGIT_CONNECTION_STRING'].
    # @param stream [#puts] Any object that respond_to?(:puts). It is used
    #   to output text somewhere e.g. a file or STDERR. Use nil for no output.
    # @param case_sensitive [Boolean] Whether character case must match.
    # @param whole_sentence [Boolean] Whether multiple words should be searched
    #   for separately.
    # @param limit [Integer] The max number of results to print.
    # @param skip [Integer] The number of DB records to skip.
    # @param sentence_limit [Integer] The max length of each result's text
    #   snippet.
    # @yield [doc] Given each search result (Wgit::Document) returned from the
    #   database.
    # @return [Array<Wgit::Document>] The search results with matching text.
    def search(
      query, connection_string: @dsl_conn_str, stream: STDOUT,
      case_sensitive: false, whole_sentence: true,
      limit: 10, skip: 0, sentence_limit: 80, &block
    )
      stream = File.open(File::NULL, 'w') unless stream
      db = Wgit::Database.new(connection_string)

      results = db.search(
        query,
        case_sensitive: case_sensitive,
        whole_sentence: whole_sentence,
        limit: limit,
        skip: skip,
        &block
      )

      results.each do |doc|
        doc.search!(
          query,
          case_sensitive: case_sensitive,
          whole_sentence: whole_sentence,
          sentence_limit: sentence_limit
        )
      end

      Wgit::Utils.printf_search_results(results, stream: stream)

      results
    end

    def clear_db!(connection_string: @dsl_conn_str)
      db = Wgit::Database.new(connection_string)
      db.clear_db
    end

    alias crawl_r crawl_site
    alias index_r index_site
  end
end
