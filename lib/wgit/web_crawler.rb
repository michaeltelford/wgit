#!/usr/bin/env ruby

require_relative 'crawler'
require_relative 'database/database'

# @author Michael Telford
module Wgit
  
  # Convience method to crawl the World Wide Web.
  # The default value (-1) for max_sites_to_crawl is unrestricted.
  # The default max_data_size is 1GB.
  def self.crawl_the_web(max_sites_to_crawl = -1, max_data_size = 1048576000)
    db = Wgit::Database.new
    web_crawler = Wgit::WebCrawler.new(db, max_sites_to_crawl, max_data_size)
    web_crawler.crawl_the_web
  end

  # Class which sets up a crawler and saves the indexed 
  # docs to a database. Will crawl the web forever if you let it :-)
  class WebCrawler
    attr_accessor :max_sites_to_crawl, :max_data_size
    attr_reader :crawler, :db
    
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
    # url's to be crawled at a later date. 
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

    # Keep crawling or not based on DB size and current loop interation.
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
