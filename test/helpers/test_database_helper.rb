require 'mongo'
require_relative "test_helper"
require_relative "test_database_default_data"
require_relative "../../lib/pinch/database/mongo_connection_details"

# @author Michael Telford
# Helper class for the Database tests to help seed and clear data. 
# The main methods include: clear, seed, num_records, url?, doc?
module TestDatabaseHelper
  
  # Log path is relative to the root project folder, not this file. 
  log_file_path = "misc/test_mongo_log.txt".freeze
  logger = Logger.new(log_file_path)
  address = "#{CONNECTION_DETAILS[:host]}:#{CONNECTION_DETAILS[:port]}"
  @@client = Mongo::Client.new([address], 
                               :database => CONNECTION_DETAILS[:db],
                               :user => CONNECTION_DETAILS[:uname],
                               :password => CONNECTION_DETAILS[:pword],
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
  def clear
    clear_urls + clear_docs
  end
  
  # Seeds what's in the block comprising of url and doc method calls
  # (in this module). If anything other than a hash is given then the default 
  # hash is used. An integer can be used to specify how many of default 
  # objects should be seeded. One is the default. 
  # Returns the number of seeded/inserted documents in the DB. 
  # Code example:
  # seed do
  #   url({ url: "http://www.google.co.uk" })
  #   doc({ url: "https://www.myserver.org", html: "<html></html>" })
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
      raise "Write to DB failed, remember that both urls and docs won't \
accept duplicate urls. Exception message: #{ex.message}"
    end
  end
  
  def num_urls
    @@client[:urls].count
  end
  
  def num_docs
    @@client[:documents].count
  end
  
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
  
private

  def url(hash_or_int = 1)
    if hash_or_int and hash_or_int.is_a?(Hash)
      @@urls << hash_or_int
    else
      hash_or_int.times { @@urls << TestDatabaseDefaultData.default_url }
    end
  end
  
  def doc(hash_or_int = 1)
    if hash_or_int and hash_or_int.is_a?(Hash)
      @@docs << hash_or_int
    else
      hash_or_int.times { @@docs << TestDatabaseDefaultData.default_doc }
    end
  end
  
  alias_method :nuke, :clear
  alias_method :document, :doc
  alias_method :document?, :doc?
  alias_method :num_documents, :num_docs
  alias_method :clear_documents, :clear_docs
end
