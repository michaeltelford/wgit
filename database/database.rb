require_relative "../documents"
require_relative "../document"
require_relative "../url"
require_relative "mongo_connection_details"
require_relative "model"
require "mongo"

# @author Michael Telford
# Class modeling a DB connection and search engine related functionality.
class Database
    def initialize
        address = "#{CONNECTION_DETAILS[:host]}:#{CONNECTION_DETAILS[:port]}"
        @client = Mongo::Client.new([address], 
                                    :database => CONNECTION_DETAILS[:db],
                                    :user => CONNECTION_DETAILS[:uname],
                                    :password => CONNECTION_DETAILS[:pword])
        Mongo::Logger.logger = nil
    end
    
    # Create Data.
    
    def insert_url(url)
        raise "url must be a Url" unless url.is_a?(Url)
        url = Model.url(url)
        create(:urls, url)
    end
    
    def insert_urls(urls)
        return insert_url(urls) unless urls.respond_to?(:map)
        urls = urls.map do |url|
            raise "urls must contain Url objects" unless url.is_a?(Url)
            Model.url(url, url.source)
        end
        create(:urls, urls)
    end
    
    def insert_doc(doc)
        unless doc.is_a?(Document) or doc.is_a?(Hash)
            raise "doc must be a Document or a Hash (from Document#to_hash)"
        end
        doc = Model.document(doc) unless doc.is_a?(Hash)
        create(:documents, doc)
    end
    
    def insert_docs(docs)
        return insert_doc(docs) unless docs.is_a?(Documents)
        docs = docs.map do |url, doc|
            Model.document(doc) unless doc.is_a?(Hash)
        end
        create(:documents, docs)
    end
    
    # Retreive Data.
    
    # A limit of 0 returns all uncrawled urls.
    def get_urls(limit = 0, crawled = false, &block)
        query = {:crawled => crawled}
        sort = {:date_added => 1}
        retrieve(:urls, query, sort, limit, &block)
    end

    # Searches against the indexed docs in the DB for the given text.
    #
    # @param text [String] the text to search the data against.
    # @param data [Array] the doc data fields to search against.
    # @param exact_search [Boolean] whether multiple words 
    # should be searched for separately.
    # @param whole_word [Boolean] whether each word in text is allowed to 
    # form part of others.
    # @param case_sensitive [Boolean] whether upper or lower case matters.
    # 
    # @return [Hash] representing the search results. Each key is the doc 
    # url and each value is an Array containing the matching text snippets 
    # for that doc.
    def search(text, data = [:text], exact_search = false, 
               whole_word = false, case_sensitive = false)
    end
    
    # Returns a Mongo object which can be used like a Hash to retrive values.
    def stats
        @client.command(:dbStats => 0).documents[0]
    end
    
    def length
        stats[:dataSize]
    end
    
    # Update Data.
    
    def update_crawled_url(url)
    end
    
private
    
    def create(collection, data)
        if data.is_a?(Hash) # Single doc.
            data.merge!(Model.common_insert_data)
            result = @client[collection.to_sym].insert_one(data)
        elsif data.is_a?(Array) # Multiple docs.
            data.map! do |data_hash|
                raise "data_hash must be a Hash" unless data_hash.is_a?(Hash)
                data_hash.merge(Model.common_insert_data)
            end
            result = @client[collection.to_sym].insert_many(data)
        else
            raise "data must be a Hash or an Array of Hash's"
        end
    end
    
    def retrieve(collection, query, sort = {}, limit = 0, &block)
        res = @client[collection].find(query).limit(limit).sort(sort)
        return res if block.nil?
        length = 0 # We count here rather than asking the DB via res.count.
        res.each do |doc|
            block.call(doc)
            length += 1
        end
        length
    end
    
    alias :to_h :stats
    alias :count :length
end
