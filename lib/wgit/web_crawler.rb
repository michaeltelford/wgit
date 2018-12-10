#!/usr/bin/env ruby

require_relative 'crawler'
require_relative 'database/database'

module Wgit
  
  # Convience method to crawl the World Wide Web using Wgit::WebCrawler.
  # 
  # @param max_sites_to_crawl [Integer] The number of separate and whole websites
  #   to be crawled before the method exits. Defaults to -1 which means the
  #   crawl will occur until manually stopped (Ctrl+C etc).
  # @param max_data_size [Integer] The maximum amount of bytes that will be
  #   scraped from the web (default is 1GB). Note, that this value is used to
  #   determine when to stop crawling; it's not a guarantee of the max data
  #   that will be obtained.
  def self.crawl_the_web(max_sites_to_crawl = -1, max_data_size = 1048576000)
    db = Wgit::Database.new
    web_crawler = Wgit::WebCrawler.new(db, max_sites_to_crawl, max_data_size)
    web_crawler.crawl_the_web
  end

  # Class which sets up a crawler and saves the indexed docs to a database. 
  # Will crawl the web forever if you let it!
  class WebCrawler
    # The max number of sites to crawl before stopping.
    attr_accessor :max_sites_to_crawl

    # The current amount of crawled data must be below this before
    # continuing to crawl a new site. Is not a max crawl gaurentee.
    attr_accessor :max_data_size

    # The crawler used to scrape the WWW.
    attr_reader :crawler
    
    # The database instance used to store Urls and Documents in.
    attr_reader :db
    
    # Initialize the WebCrawler.
    #
    # @param database [Wgit::Database] The database instance (already
    #   initialzed with the correct connection details etc).
    # @param max_sites_to_crawl [Integer] How many separate and whole websites
    #   will be crawled before the method exits. Defaults to -1 which means the
    #   crawl will occur until manually stopped (Ctrl+C etc).
    # @param max_data_size [Integer] The maximum amount of bytes that will be
    #   scraped from the web. Note, that this value is used to determine when to
    #   stop crawling; it is not a guarantee of the max data that'll be obtained.
    # @return [Wgit::WebCrawler] The new initialized instance of WebCrawler.
    def initialize(database, 
                   max_sites_to_crawl = -1, 
                   max_data_size = 1048576000)
      @crawler = Wgit::Crawler.new
      @db = database
      @max_sites_to_crawl = max_sites_to_crawl
      @max_data_size = max_data_size
    end

    # Retrieves url's from the database and recursively crawls each site 
    # storing their internal pages into the database and adding their external 
    # url's to be crawled at a later date. Puts out info on the crawl to STDOUT
    # as it goes along.
    def crawl_the_web
      if max_sites_to_crawl < 0
        puts "Crawling until the database has been filled or it runs out of \
urls to crawl (which might be never)."
      end
      loop_count = 0
      
      while keep_crawling?(loop_count) do
          puts "Current database size: #{db.size}"
          crawler.urls = db.uncrawled_urls

          if crawler.urls.empty?
              puts "No urls to crawl, exiting."
              break
          end
          puts "Starting crawl loop for: #{crawler.urls}"
      
          docs_count = 0
          urls_count = 0
      
          crawler.urls.each do |url|
            unless keep_crawling?(loop_count)
              puts "Reached max number of sites to crawl or database \
capacity, exiting."
              return
            end
            loop_count += 1

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
  
    private

    # Keep crawling or not based on DB size and current loop iteration.
    def keep_crawling?(loop_count)
      return false if db.size >= max_data_size
      # If max_sites_to_crawl is -1 for example then crawl away.
      if max_sites_to_crawl < 0
        true
      else
        loop_count < max_sites_to_crawl
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

if __FILE__ == $0
    Wgit.crawl_the_web
end
