require_relative "mongo_connection_details"
require_relative "documents"
require_relative "document"
require_relative "url"
require 'mongo'

# @author Michael Telford
# Class modeling a DB connection and search engine related functionality.
class Database
    COMMON_INSERT_DATA = {
        :date_added     => time_stamp,
        :date_modified  => time_stamp
    }
    
    attr_reader :client
    
    def initialize
        address = "#{CONNECTION_DETAILS[:host]}:#{CONNECTION_DETAILS[:port]}"
        @client = Mongo::Client.new([address], 
                                    :database => CONNECTION_DETAILS[:db],
                                    :user => CONNECTION_DETAILS[:uname],
                                    :password => CONNECTION_DETAILS[:pword])
    end
    
    # Create Data.
    
    def insert_url(url, source = nil)
        data = {
            :url            => url,
            :source         => source,
            :crawled        => false,
            :date_crawled   => time_stamp
        }
        insert(:urls, data)
    end
    
    def insert_urls(urls)
        return insert_url(urls) unless urls.respond_to?(:map)
        urls.map do |url|
            {
                :url            => url,
                :source         => source,
                :crawled        => false,
                :date_crawled   => time_stamp
            }
        end
        insert(:urls, urls, false)
    end
    
    def insert_doc(doc)
    end
    
    def insert_docs(docs)
        #
    end
    
    # Retreive Data.
    
    # limit = 0 returns all uncrawled urls.
    def get_uncrawled_urls(limit = 0)
    end
    
    def search(text, data = [:text])
    end
    
    def stats
    end
    
    # Update Data.
    
    def update_crawled_url(url)
    end
    
    private
    
    def time_stamp
        Time.new.strftime("%Y-%m-%d %H:%M:%S").to_s
    end
    
    def insert(collection, data, single = true)
        raise "data must be a Hash" unless data.is_a?(Hash)
        data.merge!(COMMON_INSERT_DATA)
        if single
            result = @client[collection.to_sym].insert_one(data)
        else
            result = @client[collection.to_sym].insert_many(data)
        end
        result.n # Return the number of inserted docs.
    end
end
