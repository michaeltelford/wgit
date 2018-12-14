require_relative 'crawler'
require_relative 'database/database'

module Wgit

  # Convience method to index the World Wide Web using
  # Wgit::Indexer#index_the_web.
  #
  # Retrieves uncrawled url's from the database and recursively crawls each
  # site storing their internal pages into the database and adding their
  # external url's to be crawled at a later date. Puts out info on the crawl
  # to STDOUT as it goes along.
  # 
  # @param max_sites_to_crawl [Integer] The number of separate and whole
  #   websites to be crawled before the method exits. Defaults to -1 which
  #   means the crawl will occur until manually stopped (Ctrl+C etc).
  # @param max_data_size [Integer] The maximum amount of bytes that will be
  #   scraped from the web (default is 1GB). Note, that this value is used to
  #   determine when to stop crawling; it's not a guarantee of the max data
  #   that will be obtained.
  def self.index_the_web(max_sites_to_crawl = -1, max_data_size = 1048576000)
    db = Wgit::Database.new
    indexer = Wgit::Indexer.new(db)
    indexer.index_the_web(max_sites_to_crawl, max_data_size)
  end

  # Convience method to index a single website using
  # Wgit::Indexer#index_this_site.
  #
  # Crawls a single website's pages and stores them into the database.
  # There is no max download limit so be careful which sites you index.
  #
  # @param url [Wgit::Url, String] The base Url of the website to crawl.
  # @param insert_externals [Boolean] Whether or not to insert the website's
  #   external Url's into the database.
  # @yield [doc] Given the Wgit::Document of each crawled web page, before it
  #   is inserted into the database allowing for prior manipulation.
  # @return [Integer] The total number of pages crawled within the website.
  def self.index_this_site(url, insert_externals = true, &block)
    url = Wgit::Url.new url
    db = Wgit::Database.new
    indexer = Wgit::Indexer.new(db)
    indexer.index_this_site(url, insert_externals, &block)
  end

  # Performs a search of the database's indexed documents and pretty prints
  # the results. See Wgit::Database#search for details of the search.
  #
  # @param query [String] The text query to search with.
  # @param whole_sentence [Boolean] Whether multiple words should be searched
  #   for separately.
  # @param limit [Integer] The max number of results to return.
  # @param skip [Integer] The number of DB records to skip.
  # @param sentence_length [Integer] The max length of each result's text
  #   snippet.
  # @yield [doc] Given each search result (Wgit::Document).
  def self.indexed_search(query, whole_sentence = false, limit = 10, 
                     skip = 0, sentence_length = 80, &block)
    db = Wgit::Database.new
    results = db.search(query, whole_sentence, limit, skip, &block)
    Wgit::Utils.printf_search_results(results, query, false, sentence_length)
  end

  # Class which sets up a crawler and saves the indexed docs to a database.
  class Indexer
    
    # The crawler used to scrape the WWW.
    attr_reader :crawler
    
    # The database instance used to store Urls and Documents in.
    attr_reader :db
    
    # Initialize the Indexer.
    #
    # @param database [Wgit::Database] The database instance (already
    #   initialized with the correct connection details etc).
    def initialize(database)
      @crawler = Wgit::Crawler.new
      @db = database
    end

    # Retrieves uncrawled url's from the database and recursively crawls each
    # site storing their internal pages into the database and adding their
    # external url's to be crawled at a later date. Puts out info on the crawl
    # to STDOUT as it goes along.
    #
    # @param max_sites_to_crawl [Integer] The number of separate and whole
    #   websites to be crawled before the method exits. Defaults to -1 which
    #   means the crawl will occur until manually stopped (Ctrl+C etc).
    # @param max_data_size [Integer] The maximum amount of bytes that will be
    #   scraped from the web (default is 1GB). Note, that this value is used to
    #   determine when to stop crawling; it's not a guarantee of the max data
    #   that will be obtained.
    def index_the_web(max_sites_to_crawl = -1, max_data_size = 1048576000)
      if max_sites_to_crawl < 0
        puts "Indexing until the database has been filled or it runs out of \
urls to crawl (which might be never)."
      end
      site_count = 0
      
      while keep_crawling?(site_count, max_sites_to_crawl, max_data_size) do
        puts "Current database size: #{db.size}"
        crawler.urls = db.uncrawled_urls

        if crawler.urls.empty?
            puts "No urls to crawl, exiting."
            return
        end
        puts "Starting crawl loop for: #{crawler.urls}"
    
        docs_count = 0
        urls_count = 0
    
        crawler.urls.each do |url|
          unless keep_crawling?(site_count, max_sites_to_crawl, max_data_size)
            puts "Reached max number of sites to crawl or database \
capacity, exiting."
            return
          end
          site_count += 1

          url.crawled = true
          raise unless db.update(url) == 1
      
          site_docs_count = 0
          ext_links = crawler.crawl_site(url) do |doc|
              unless doc.empty?
                  if write_doc_to_db(doc)
                      docs_count += 1
                      site_docs_count += 1
                  end
              end
          end
      
          urls_count += write_urls_to_db(ext_links)
          puts "Crawled and saved #{site_docs_count} docs for the \
site: #{url}"
        end

        puts "Crawled and saved docs for #{docs_count} url(s) overall for \
this iteration."
        puts "Found and saved #{urls_count} external url(s) for the next \
iteration."
      end
    end

    # Crawls a single website's pages and stores them into the database.
    # There is no max download limit so be careful which sites you index.
    #
    # @param url [Wgit::Url] The base Url of the website to crawl.
    # @param insert_externals [Boolean] Whether or not to insert the website's
    #   external Url's into the database.
    # @yield [doc] Given the Wgit::Document of each crawled web page, before it
    #   is inserted into the database allowing for prior manipulation.
    # @return [Integer] The total number of pages crawled within the website.
    def index_this_site(url, insert_externals = true)
      total_pages_crawled = 0
      
      ext_urls = crawler.crawl_site(url) do |doc|
        yield(doc) if block_given?
        inserted = write_doc_to_db(doc)
        total_pages_crawled += 1 if inserted
      end

      url.crawled = true
      if !db.url?(url)
        db.insert(url)
      else
        db.update(url)
      end
      
      write_urls_to_db(ext_urls) if insert_externals
      
      total_pages_crawled
    end

    private

    # Keep crawling or not based on DB size and current loop iteration.
    def keep_crawling?(site_count, max_sites_to_crawl, max_data_size)
      return false if db.size >= max_data_size
      # If max_sites_to_crawl is -1 for example then crawl away.
      if max_sites_to_crawl < 0
        true
      else
        site_count < max_sites_to_crawl
      end
    end

    # The unique url index on the documents collection prevents duplicate 
    # inserts.
    def write_doc_to_db(doc)
        db.insert(doc)
        puts "Saved document for url: #{doc.url}"
        true
    rescue Mongo::Error::OperationFailure
        puts "Document already exists: #{doc.url}"
        false
    end

    # The unique url index on the urls collection prevents duplicate inserts.
    def write_urls_to_db(urls)
        count = 0
        if urls.respond_to?(:each)
            urls.each do |url|
                begin
                  db.insert(url)
                  count += 1
                  puts "Inserted url: #{url}"
                rescue Mongo::Error::OperationFailure
                  puts "Url already exists: #{url}"
                end
            end
        end
        count
    end
  end
end
