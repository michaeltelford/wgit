require_relative '../documents'
require_relative '../document'
require_relative '../url'
require_relative 'mongo_connection_details'
require_relative 'model'
require 'mongo'

# @author Michael Telford
# Class modeling a DB connection and search engine related functionality.
class Database
    LOG_FILE_PATH = "database/mongo_log.txt"
    
    def initialize
        logger = Logger.new(LOG_FILE_PATH)
        address = "#{CONNECTION_DETAILS[:host]}:#{CONNECTION_DETAILS[:port]}"
        @client = Mongo::Client.new([address], 
                                    :database => CONNECTION_DETAILS[:db],
                                    :user => CONNECTION_DETAILS[:uname],
                                    :password => CONNECTION_DETAILS[:pword],
                                    :logger => logger)
    end
    
    # Create Data.
    
    def insert(data)
        if data.is_a?(Url)
            insert_url(data)
        elsif data.is_a?(Document)
            insert_doc(data)
        elsif data.respond_to?(:map)
            if data[0].is_a?(Url)
                insert_urls(data)
            else
                insert_docs(data)
            end
        else
            raise "data class/type not currently supported"
        end
    end
    
    def insert_url(url)
        Utils.is_a?(url, Url, "url must be a Url")
        url = Model.url(url)
        create(:urls, url)
    end
    
    def insert_urls(urls)
        return insert_url(urls) unless urls.respond_to?(:map)
        urls = urls.map do |url|
            Utils.is_a?(url, Url, "urls must contain Url objects")
            Model.url(url)
        end
        create(:urls, urls)
    end
    
    def insert_doc(doc)
        Utils.is_a?(doc, [Document, Hash], 
            "doc must be a Document or a Hash (from Document#to_hash)")
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
    def get_urls(crawled = false, limit = 0, &block)
        query = {:crawled => crawled}
        sort = {:date_added => 1}
        retrieve(:urls, query, sort, limit, &block)
    end

    # Searches against the indexed docs in the DB for the given text.
    #
    # @param text [String] the text to search the data against.
    # @param data [Array] the doc data fields to search against.
    # @param whole_sentence [Boolean] whether multiple words 
    # should be searched for separately.
    # @param whole_word [Boolean] whether each word in text is allowed to 
    # form part of others.
    # @param case_sensitive [Boolean] whether upper or lower case matters.
    # 
    # @return [Hash] representing the search results. Each key is the doc 
    # url and each value is an Array containing the matching text snippets 
    # for that doc.
    def search(text, data = [:text], whole_sentence = false, 
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
    
    def update_crawled_urls(url_or_urls)
        Utils.is_a?(url_or_urls, Url, "A Url or Array of Urls is expected")
        if url_or_urls.respond_to?(:each)
            single = false
            selection = { :url => { "$in" => url_or_urls } }
        else
            single = true
            selection = { :url => url_or_urls }
        end
        update = { "$set" => { :crawled => true } }
        update(single, :urls, selection, update) # { upsert: true|false }
    end
    
private

    def write_succeeded?(result, count = 1, multi = false)
        case result.class.to_s
        # Single create result.
        when "Mongo::Operation::Write::Insert::Result"
            result.documents[0][:err].nil?
        # Multiple create result.
        when "Mongo::BulkWrite::Result"
            result.inserted_count == count
        # Single and multiple update result.
        when "Mongo::Operation::Write::Update::LegacyResult"
            if multi
                result.n == count
            else
                result.documents[0][:err].nil?
            end
        else
            raise "result class not currently supported"
        end
    end
    
    def create(collection, data)
        # Single doc.
        if data.is_a?(Hash)
            data.merge!(Model.common_insert_data)
            result = @client[collection.to_sym].insert_one(data)
            raise "DB write (insert) failed" unless write_succeeded?(result)
            result
        # Multiple docs.
        elsif data.is_a?(Array)
            data.map! do |data_hash|
                Utils.is_a?(data_hash, Hash, "data must be an Array of Hash's")
                data_hash.merge(Model.common_insert_data)
            end
            result = @client[collection.to_sym].insert_many(data)
            unless write_succeeded?(result, data.length)
                raise "DB write(s) failed"
            end
            result
        else
            raise "data must be a Hash or an Array of Hash's"
        end
    end
    
    def retrieve(collection, query, sort = {}, limit = 0, &block)
        result = @client[collection].find(query).limit(limit).sort(sort)
        return result if block.nil?
        length = 0 # We count here rather than asking the DB via res.count.
        result.each do |obj|
            block.call(obj)
            length += 1
        end
        length
    end
    
    def update(single, collection, selection, update)
        if single
            result = @client[collection.to_sym].update_one(selection, update)
            raise "DB write (update) failed" unless write_succeeded?(result)
        else
            result = @client[collection.to_sym].update_many(selection, update)
            raise "DB write (update) failed" unless write_succeeded?(result)
        end
        result.n
    end
    
    alias :count :length
    alias :size :length
    alias :urls :get_urls
    alias :update_crawled_url :update_crawled_urls
end
