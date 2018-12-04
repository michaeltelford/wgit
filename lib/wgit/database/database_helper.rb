require_relative "database_default_data"
require_relative "mongo_connection_details"
require 'mongo'

module Wgit

  # @author Michael Telford
  # Helper class for the Database to manipulate data. Used for testing and 
  # development. This class isn't packaged in the gem and is for dev only so it 
  # doesn't currently have unit tests. This class was originally 
  # developed to assist in testing database.rb and is in essence tested by the 
  # database tests themselves as they use the helper methods. 
  # The main methods include: clear_db (nuke), seed, num_records, num_urls, 
  # num_docs, url?, doc?, index, search
  module DatabaseHelper
    conn_details = Wgit::CONNECTION_DETAILS
    if conn_details.empty?
      raise "Wgit::CONNECTION_DETAILS must be defined and include :host, 
:port, :db, :uname, :pword for a database connection to be established."
    end
  
    # Log path is relative to the root project folder, not this file. 
    log_file_path = "misc/test_mongo_log.txt".freeze
    logger = Logger.new(log_file_path)
    address = "#{conn_details[:host]}:#{conn_details[:port]}"
      
    @@client = Mongo::Client.new([address], 
                                 :database => conn_details[:db],
                                 :user => conn_details[:uname],
                                 :password => conn_details[:pword],
                                 :logger => logger,
                                 :truncate_logs => false)
  
    @@urls = []
    @@docs = []
    
    # Returns the number of deleted records.
    def clear_urls
      @@client[:urls].delete_many({}).n
    end

    # Returns the number of deleted records.  
    def clear_docs
      @@client[:documents].delete_many({}).n
    end
  
    # Returns the number of deleted records.
    def clear_db
      clear_urls + clear_docs
    end
  
    # Seeds what's in the block comprising of url and doc method calls
    # (in this module). If anything other than a hash is given then the default 
    # hash is used. An integer can be used to specify how many of default 
    # objects should be seeded. One is the default. 
    # Returns the number of seeded/inserted documents in the DB. 
    # Code example:
    # seed do
    #   url(url: "http://www.google.co.uk")
    #   doc(url: "https://www.myserver.org", html: "<html></html>")
    #   url 3   # Seeds 3 of the default url records.
    #   doc     # Seeds 1 of the default doc records.
    # end
    def seed(&block)
      raise "Must provide a block" unless block_given?
    
      @@urls.clear
      @@docs.clear
    
      # &block populates the @@urls and @@docs arrays.
      instance_eval(&block)
    
      begin
        @@client[:urls].insert_many(@@urls)
        @@client[:documents].insert_many(@@docs)
      
        @@urls.count + @@docs.count
      rescue Exception => ex
        err_msg = ex.message
        err_msg = ex.result["writeErrors"] if ex.respond_to?(:result)
        raise "Write to DB failed, remember that both urls and docs won't \
accept duplicate urls. Exception details: #{err_msg}"
      end
    end
  
    # Returns the total number of URL records in the DB.
    def num_urls
      @@client[:urls].count
    end
  
    # Returns the total number of Document records in the DB.
    def num_docs
      @@client[:documents].count
    end
  
    # Returns the total number of records (urls + docs) in the DB.
    def num_records
      num_urls + num_docs
    end
  
    # Returns wether a url exists with the given url field.
    # Default checks if the urls collection has at least one document in it.
    def url?(url = {})
      not @@client[:urls].find(url).none?
    end
  
    # Returns wether a doc exists with the given url field.
    def doc?(doc = {})
      not @@client[:documents].find(doc).none?
    end
    
    # Helper method which takes a url and recursively indexes the site storing 
    # the markup in the database. Use sensible url's e.g. not Amazon.co.uk. 
    # We re-use the private methods of WebCrawler to handle error scenarios 
    # and put statements when interacting with the database. 
    def index(url, insert_externals = true)
      crawler = Wgit::Crawler.new url
      database = Wgit::Database.new
      web_crawler = Wgit::WebCrawler.new database
      
      total_crawled = 0
      
      ext_urls = crawler.crawl_site do |doc|
        inserted = web_crawler.send :write_doc_to_db, doc
        total_crawled += 1 if inserted
      end
      
      web_crawler.send :write_urls_to_db, ext_urls
      
      total_crawled
    end
    
    # Searches the database Document collection for the given text, formats 
    # and pretty prints the results for the command line. Mainly used for 
    # ./bin/console. 
    def search(query)
      Database.new.search_p query
    end
  
  private

    def url(hashes_or_int = 1)
      if hashes_or_int and hash_or_array?(hashes_or_int)
        if hashes_or_int.is_a?(Hash)
          @@urls << hashes_or_int
        else
          @@urls.concat(hashes_or_int)
        end
      else
        hashes_or_int.times { @@urls << Wgit::DatabaseDefaultData.url }
      end
    end
  
    def doc(hashes_or_int = 1)
      if hashes_or_int and hash_or_array?(hashes_or_int)
        if hashes_or_int.is_a?(Hash)
          @@docs << hashes_or_int
        else
          @@docs.concat(hashes_or_int)
        end
      else
        hashes_or_int.times { @@docs << Wgit::DatabaseDefaultData.doc }
      end
    end
  
    def hash_or_array?(obj)
      obj.is_a?(Hash) or obj.is_a?(Array)
    end
  
    alias_method :nuke, :clear_db
    alias_method :document, :doc
    alias_method :document?, :doc?
    alias_method :num_documents, :num_docs
    alias_method :clear_documents, :clear_docs
    alias_method :urls, :url
    alias_method :docs, :doc
  end
end
