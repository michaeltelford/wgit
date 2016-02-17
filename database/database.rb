require_relative '../document'
require_relative '../url'
require_relative '../utils'
require_relative 'mongo_connection_details'
require_relative 'model'
require 'mongo'

# @author Michael Telford
# Class modeling a DB connection and search engine related functionality.
class Database
    LOG_FILE_PATH = "database/mongo_log.txt"
    
    ### TODO: REMOVE TEMP LINE, FOR DEV ONLY. ###
    attr_reader :client
    
    def initialize
        logger = Logger.new(LOG_FILE_PATH)
        address = "#{CONNECTION_DETAILS[:host]}:#{CONNECTION_DETAILS[:port]}"
        @client = Mongo::Client.new([address], 
                                    :database => CONNECTION_DETAILS[:db],
                                    :user => CONNECTION_DETAILS[:uname],
                                    :password => CONNECTION_DETAILS[:pword],
                                    :logger => logger,
                                    :truncate_logs => false)
    end
    
    # Create Data.
    
    def insert(data)
        if data.is_a?(Url)
            insert_urls(data)
        elsif data.is_a?(Document)
            insert_docs(data)
        elsif data.respond_to?(:map)
            if data.first.is_a?(Url)
                insert_urls(data)
            else
                insert_docs(data)
            end
        else
            raise "data class/type not currently supported"
        end
    end
    
    def insert_urls(url_or_urls)
        Utils.assert_type?(url_or_urls, Url)
        unless url_or_urls.respond_to?(:map)
            url_or_urls = Model.url(url_or_urls)
        else
            url_or_urls = url_or_urls.map do |url|
                Model.url(url)
            end
        end
        create(:urls, url_or_urls)
    end
    
    def insert_docs(doc_or_docs)
        Utils.assert_type?(doc_or_docs, [Document, Hash])
        unless doc_or_docs.respond_to?(:each)
            unless doc_or_docs.is_a?(Hash)
                doc_or_docs = Model.document(doc_or_docs)
            end
        else
            doc_or_docs = doc_or_docs.map do |doc|
                Model.document(doc) unless doc.is_a?(Hash)
            end
        end
        create(:documents, doc_or_docs)
    end
    
    # Retreive Data.
    
    # A limit of 0 returns all uncrawled urls.
    def get_urls(crawled = false, limit = 0, skip = 0, &block)
        crawled.nil? ? query = {} : query = { :crawled => crawled }
        sort = { :date_added => 1 }
        results = retrieve(:urls, query, sort, {}, limit, skip, &block)
        if results.respond_to?(:map)
            results = results.map { |url_doc| Url.new(url_doc) }
        end
        return results if block.nil?
        results.each { |url| block.call(url) }
    end

    # Searches against the indexed docs in the DB for the given text.
    # The searched fields are decided by the text index setup against the 
    # documents collection. Currently we search against the following fields:
    # "author", "keywords", "title" and "text".
    #
    # @param text [String] the text to search the data against.
    # @param whole_sentence [Boolean] whether multiple words should be 
    # searched for separately.
    # @param limit [Fixnum] the max length/count of the results array.
    # @param skip [Fixnum] the number of results to skip, starting with the 
    # most relevant based upon the textScore of the search. 
    # @param block [Block] a block which is passed each result if provided. 
    # 
    # @return [Array] of search result objects.
    def search(text, whole_sentence = false, limit = 10, skip = 0, &block)
        text.strip!
        text.replace("\"" + text + "\"") if whole_sentence
        
        # The textScore sorts based on the most search hits.
        # We use the textScore hash as a sort and a projection below.
        sort_proj = { :score => { :$meta => "textScore" } }
        #:$caseSensitive => case_sensitive, # 3.2+ only.
        query = { :$text => { :$search => text } }
        results = retrieve(:documents, query, sort_proj, sort_proj, 
                           limit, skip, &block)
        
        return [] if results.count < 1
        results.map do |mongo_doc|
            Document.new(mongo_doc)
        end
    end
    
    # Returns a Mongo object which can be used like a Hash to retrieve values.
    def stats
        @client.command(:dbStats => 0).documents[0]
    end
    
    def length
        stats[:dataSize]
    end
    
    # Update Data.
    
    def update(data)
        if data.is_a?(Url)
            update_url(data)
        elsif data.is_a?(Document)
            update_doc(data)
        else
            raise "data class/type not currently supported"
        end
    end
    
    def update_url(url)
        Utils.assert_type?([url], Url)
        selection = { :url => url }
        url_hash = Model.url(url).merge(Model.common_update_data)
        update = { "$set" => url_hash }
        _update(true, :urls, selection, update)
    end
    
    def update_doc(doc)
        Utils.assert_type?([doc], Document)
        selection = { :url => doc.url }
        doc_hash = Model.document(doc).merge(Model.common_update_data)
        update = { "$set" => doc_hash }
        _update(true, :documents, selection, update)
    end
    
private

    def write_succeeded?(result, count = 1, multi = false)
        case result.class.to_s
        # Single create result.
        when "Mongo::Operation::Write::Insert::Result"
            result.documents.first[:err].nil?
        # Multiple create result.
        when "Mongo::BulkWrite::Result"
            result.inserted_count == count
        # Single and multiple update result.
        when "Mongo::Operation::Write::Update::Result", # MongoDB 3.0
             "Mongo::Operation::Write::Update::LegacyResult" # MongoDB 2.4
            if multi
                result.n == count
            else
                result.documents.first[:err].nil?
            end
        else
            raise "Result class not currently supported: #{result.class.to_s}"
        end
    end
    
    def create(collection, data)
        Utils.assert_type?(data, Hash)
        # Single doc.
        if data.is_a?(Hash)
            data.merge!(Model.common_insert_data)
            result = @client[collection.to_sym].insert_one(data)
            raise "DB write (insert) failed" unless write_succeeded?(result)
            result
        # Multiple docs.
        elsif data.is_a?(Array)
            data.map! do |data_hash|
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
    
    def retrieve(collection, query, sort = {}, projection = {}, 
                 limit = 0, skip = 0, &block)
        Utils.assert_type?([query], Hash)
        result = @client[collection.to_sym].find(query).projection(projection)
                 .skip(skip).limit(limit).sort(sort)
        return result if block.nil?
        result.each do |obj|
            block.call(obj)
        end
    end
    
    # NOTE: The Model.common_update_data should be merged in the calling 
    # method as the update param can be bespoke due to its nature.
    def _update(single, collection, selection, update)
        Utils.assert_type?([selection, update], Hash)
        if single
            result = @client[collection.to_sym].update_one(selection, update)
        else
            result = @client[collection.to_sym].update_many(selection, update)
        end
        raise "DB write (update) failed" unless write_succeeded?(result)
        result.n
    end
    
    alias :count :length
    alias :size :length
    alias :insert_url :insert_urls
    alias :insert_doc :insert_docs
    alias :urls :get_urls
end
