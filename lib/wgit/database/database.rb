require_relative '../document'
require_relative '../url'
require_relative '../utils'
require_relative '../assertable'
require_relative 'mongo_connection_details'
require_relative 'model'
require 'mongo'

module Wgit

  # @author Michael Telford
  # Class modeling a DB connection and CRUD operations for the Url and 
  # Document collections.
  # The most common methods are: insert, update, urls, search, stats, size. 
  class Database
    include Assertable
  
    # Is relative to the root project folder, not this file. 
    LOG_FILE_PATH = "misc/mongo_log.txt"
  
    def initialize
      conn_details = Wgit::CONNECTION_DETAILS
      if conn_details.empty?
        raise "Wgit::CONNECTION_DETAILS must be defined and include :host, 
:port, :db, :uname, :pword for a database connection to be established."
      end
      
      logger = Logger.new(LOG_FILE_PATH)
      address = "#{conn_details[:host]}:#{conn_details[:port]}"
      @@client = Mongo::Client.new([address], 
                                   :database => conn_details[:db],
                                   :user => conn_details[:uname],
                                   :password => conn_details[:pword],
                                   :logger => logger,
                                   :truncate_logs => false)
    end
  
    ### Create Data ###
  
    def insert(data)
        if data.is_a?(Url)
            insert_urls(data)
        elsif data.is_a?(Document)
            insert_docs(data)
        elsif data.respond_to?(:first)
            if data.first.is_a?(Url)
                insert_urls(data)
            else
                insert_docs(data)
            end
        else
            raise "data is not in the correct format (all Url's or Document's)"
        end
    end
  
    def insert_urls(url_or_urls)
        unless url_or_urls.respond_to?(:map)
            assert_type(url_or_urls, Url)
            url_or_urls = Wgit::Model.url(url_or_urls)
        else
            assert_arr_types(url_or_urls, Url)
            url_or_urls = url_or_urls.map do |url|
                Wgit::Model.url(url)
            end
        end
        create(:urls, url_or_urls)
    end
  
    def insert_docs(doc_or_docs)
        unless doc_or_docs.respond_to?(:map)
            assert_type(doc_or_docs, [Document, Hash])
            unless doc_or_docs.is_a?(Hash)
                doc_or_docs = Wgit::Model.document(doc_or_docs)
            end
        else
            assert_arr_types(doc_or_docs, [Document, Hash])
            doc_or_docs = doc_or_docs.map do |doc|
                Wgit::Model.document(doc) unless doc.is_a?(Hash)
            end
        end
        create(:documents, doc_or_docs)
    end
  
    ### Retrieve Data ###
  
    # A crawled parameter value of nil (the default) returns all urls.
    # A limit of 0 means all urls are returned.
    def urls(crawled = nil, limit = 0, skip = 0, &block)
      crawled.nil? ? query = {} : query = { :crawled => crawled }
      
      sort = { :date_added => 1 }
      results = retrieve(:urls, query, sort, {}, limit, skip)
      return [] if results.count < 1
      
      # results.respond_to? :map! is false so we use map and overwrite the var.
      results = results.map { |url_doc| Wgit::Url.new(url_doc) }
      return results unless block_given?
      results.each { |url| block.call(url) }
    end
  
    def crawled_urls(limit = 0, skip = 0, &block)
      urls(true, limit, skip, &block)
    end
  
    def uncrawled_urls(limit = 0, skip = 0, &block)
      urls(false, limit, skip, &block)
    end

    # Currently all searches are case insensitive.
    #
    # Searches against the indexed docs in the DB for the given text.
    # The searched fields are decided by the text index setup against the 
    # documents collection. Currently we search against the following fields:
    # "author", "keywords", "title" and "text".
    #
    # The MongoDB search ranks/sorts the results in order (highest first) based 
    # upon each documents textScore which records the number of text hits. We 
    # then store this textScore in each Document object for use elsewhere if 
    # needed. 
    #
    # @param text [String] the value to search the data against.
    # @param whole_sentence [Boolean] whether multiple words should be 
    # searched for separately.
    # @param limit [Fixnum] the max length/count of the results array.
    # @param skip [Fixnum] the number of results to skip, starting with the 
    # most relevant based upon the textScore of the search. 
    # @param block [Block] a block which if provided is passed to each result. 
    # 
    # @return [Array] of Document objects representing the search results.
    def search(text, whole_sentence = false, limit = 10, skip = 0, &block)
      text.strip!
      text.replace("\"" + text + "\"") if whole_sentence
    
      # The textScore sorts based on the most search hits.
      # We use the textScore hash as a sort and a projection below.
      # :$caseSensitive => case_sensitive, # 3.2+ only.
      sort_proj = { :score => { :$meta => "textScore" } }
      query = { :$text => { :$search => text } }
      results = retrieve(:documents, query, sort_proj, sort_proj, 
                         limit, skip)
    
      return [] if results.count < 1
      # results.respond_to? :map! is false so we use map and overwrite the var.
      results = results.map { |mongo_doc| Wgit::Document.new(mongo_doc) }
      return results unless block_given?
      results.each { |doc| block.call(doc) }
    end

    # Performs a search and pretty prints the results.
    def search_p(text, whole_sentence = false, limit = 10, 
                 skip = 0, sentence_length = 80, &block)
      results = search(text, whole_sentence, limit, skip, &block)
      Wgit::Utils.printf_search_results(results, text, false, sentence_length)
    end
  
    # Returns a Mongo object which can be used like a Hash to retrieve values.
    def stats
        @@client.command(:dbStats => 0).documents[0]
    end
  
    def size
        stats[:dataSize]
    end
  
    ### Update Data ###
  
    def update(data)
      if data.is_a?(Url)
        update_url(data)
      elsif data.is_a?(Document)
        update_doc(data)
      else
        raise "data is not in the correct format (all Url's or Document's)"
      end
    end
  
    def update_url(url)
      assert_type(url, Url)
      selection = { :url => url }
      url_hash = Wgit::Model.url(url).merge(Wgit::Model.common_update_data)
      update = { "$set" => url_hash }
      _update(true, :urls, selection, update)
    end
  
  def update_doc(doc)
    assert_type(doc, Document)
    selection = { :url => doc.url }
    doc_hash = Wgit::Model.document(doc).merge(Wgit::Model.common_update_data)
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
        assert_type(data, [Hash, Array])
        # Single doc.
        if data.is_a?(Hash)
            data.merge!(Wgit::Model.common_insert_data)
            result = @@client[collection.to_sym].insert_one(data)
            unless write_succeeded?(result)
              raise "DB write (insert) failed"
            end
            result.n
        # Multiple docs.
        elsif data.is_a?(Array)
            assert_arr_types(data, Hash)
            data.map! do |data_hash|
                data_hash.merge(Wgit::Model.common_insert_data)
            end
            result = @@client[collection.to_sym].insert_many(data)
            unless write_succeeded?(result, data.length)
                raise "DB write(s) failed"
            end
            result.inserted_count
        else
            raise "data must be a Hash or an Array of Hash's"
        end
    end
  
    def retrieve(collection, query, sort = {}, projection = {}, 
                 limit = 0, skip = 0)
        assert_type(query, Hash)
        @@client[collection.to_sym].find(query).projection(projection)
                                  .skip(skip).limit(limit).sort(sort)
    end
  
    # NOTE: The Model.common_update_data should be merged in the calling 
    # method as the update param can be bespoke due to its nature.
    def _update(single, collection, selection, update)
        assert_arr_types([selection, update], Hash)
        if single
          result = @@client[collection.to_sym].update_one(selection, update)
        else
          result = @@client[collection.to_sym].update_many(selection, update)
        end
        raise "DB write (update) failed" unless write_succeeded?(result)
        result.n
    end
  
    alias :count :size
    alias :length :size
    alias :insert_url :insert_urls
    alias :insert_doc :insert_docs
  end
end
