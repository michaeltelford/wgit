require_relative "documents"
require_relative "document"
require_relative "url"
require 'mongo'

# @author Michael Telford
# Class modeling a DB connection and search engine related functionality.
class Database
    CONNECTION_DETAILS = {
        :host   => "127.0.0.1",
        :port   => "27017",
        :db     => "crawler",
        :uname  => "admin",
        :pword  => "R5jUKv1fessb"
    }
    
    attr_reader :client
    
    def initialize
        address = "#{CONNECTION_DETAILS[:host]}:#{CONNECTION_DETAILS[:port]}"
        @client = Mongo::Client.new([address], 
                                    :database => CONNECTION_DETAILS[:db],
                                    :user => CONNECTION_DETAILS[:uname],
                                    :password => CONNECTION_DETAILS[:pword])
    end
    
    # Insert Data.
    
    def insert_urls(urls)
        unless urls.respond_to?(:each)
            insert_url(urls)
        else
            urls.each { |url| insert_url(url) }
        end
    end
    
    def insert_docs(docs)
        unless docs.respond_to?(:each)
            insert_doc(docs)
        else
            docs.each { |doc| insert_doc(doc) }
        end
    end
    
    # Reteive Data.
    
    # limit = 0 returns all uncrawled urls.
    def get_uncrawled_urls(limit = 0)
    end
    
    def search(text, data = [:text])
    end
    
    private
    
    def insert_url(url)
    end
    
    def insert_doc(doc)
    end
end
