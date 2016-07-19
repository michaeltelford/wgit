require_relative "test_helper"
require_relative "../lib/pinch/database/mongo_connection_details"
require 'mongo'

# @author Michael Telford
module TestDatabaseHelper
  # Is relative to the root project folder, not this file. 
  LOG_FILE_PATH = "misc/test_mongo_log.txt"
  
  logger = Logger.new(LOG_FILE_PATH)
  address = "#{CONNECTION_DETAILS[:host]}:#{CONNECTION_DETAILS[:port]}"
  client = Mongo::Client.new([address], 
                             :database => CONNECTION_DETAILS[:db],
                             :user => CONNECTION_DETAILS[:uname],
                             :password => CONNECTION_DETAILS[:pword],
                             :logger => logger,
                             :truncate_logs => false)
                             
  def clear_urls
  end
  
  def clear_docs
  end
  
  def clear_data
    clear_urls
    clear_docs
  end
  
  def seed_urls
  end
  
  def seed_docs
  end
  
  def seed_data
    seed_urls
    seed_docs
  end
end
