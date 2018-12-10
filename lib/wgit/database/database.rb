require_relative '../document'
require_relative '../url'
require_relative '../utils'
require_relative '../assertable'
require_relative 'mongo_connection_details'
require_relative 'model'
require 'mongo'

module Wgit

  # Class modeling a DB connection and CRUD operations for the Url and 
  # Document collections. The most common methods are:
  # :insert, :update, :urls, :search, :stats, :size. 
  class Database
    include Assertable
  
    # Path is relative to the root project folder, not this file.
    LOG_FILE_PATH = "misc/mongo_log.txt".freeze

    # Initializes a database connection client.
    #
    # @raise [RuntimeError] If Wgit::CONNECTION_DETAILS aren't set.
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
  
    # Insert one or more Url or Document objects into the DB.
    #
    # @param data [Hash, Enumerable<Hash>] Hash(es) returned from
    #   Wgit::Model.url or Wgit::Model.document.
    # @raise [RuntimeError] If the data is not valid.
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
  
    ### Retrieve Data ###
  
    # Returns Url records from the DB. All Urls are sorted by date_added
    # ascending, in other words the first url returned is the first one that
    # was inserted into the DB.
    #
    # @param crawled [Boolean] Filter by Url#crawled value. nil returns all.
    # @param limit [Integer] The max number of Url's to return. 0 returns all.
    # @param skip [Integer] Skip n amount of Url's.
    # @yield [url] Given each Url returned from the DB.
    # @return [Array<Wgit::Url>] The Urls obtained from the DB.
    def urls(crawled = nil, limit = 0, skip = 0, &block)
      crawled.nil? ? query = {} : query = { crawled: crawled }
      
      sort = { date_added: 1 }
      results = retrieve(:urls, query, sort, {}, limit, skip)
      return [] if results.count < 1
      
      # results.respond_to? :map! is false so we use map and overwrite the var.
      results = results.map { |url_doc| Wgit::Url.new(url_doc) }
      return results unless block_given?
      results.each { |url| block.call(url) }
    end
  
    # Returns Url records that have been crawled.
    #
    # @param limit [Integer] The max number of Url's to return. 0 returns all.
    # @param skip [Integer] Skip n amount of Url's.
    # @yield [url] Given each Url returned from the DB.
    # @return [Array<Wgit::Url>] The crawled Urls obtained from the DB.
    def crawled_urls(limit = 0, skip = 0, &block)
      urls(true, limit, skip, &block)
    end
  
    # Returned Url records that haven't been crawled. Each Url is yielded to a
    # block, if given.
    #
    # @param limit [Integer] The max number of Url's to return. 0 returns all.
    # @param skip [Integer] Skip n amount of Url's.
    # @yield [url] Given each Url returned from the DB.
    # @return [Array<Wgit::Url>] The uncrawled Urls obtained from the DB.
    def uncrawled_urls(limit = 0, skip = 0, &block)
      urls(false, limit, skip, &block)
    end

    # Searches against the indexed docs in the DB for the given query.
    #
    # Currently all searches are case insensitive.
    #
    # The searched fields are decided by the text index setup against the
    # documents collection. Currently we search against the following fields:
    # "author", "keywords", "title" and "text".
    #
    # The MongoDB search ranks/sorts the results in order (highest first) based
    # upon each documents textScore which records the number of query hits. We
    # then store this textScore in each Document result object for use
    # elsewhere if needed.
    #
    # @param query [String] The text query to search with.
    # @param whole_sentence [Boolean] Whether multiple words should be searched
    #   for separately.
    # @param limit [Integer] The max number of results to return.
    # @param skip [Integer] The number of DB records to skip.
    # @yield [doc] Given each search result (Wgit::Document).
    # @return [Array<Wgit::Document>] The search results obtained from the DB.
    def search(query, whole_sentence = false, limit = 10, skip = 0, &block)
      query.strip!
      query.replace("\"" + query + "\"") if whole_sentence
    
      # The sort_proj sorts based on the most search hits.
      # We use the sort_proj hash as both a sort and a projection below.
      # :$caseSensitive => case_sensitive, 3.2+ only.
      sort_proj = { score: { :$meta => "textScore" } }
      query = { :$text => { :$search => query } }
      results = retrieve(:documents, query, sort_proj, sort_proj, limit, skip)
    
      return [] if results.count < 1
      # results.respond_to? :map! is false so we use map and overwrite the var.
      results = results.map { |mongo_doc| Wgit::Document.new(mongo_doc) }
      return results unless block_given?
      results.each { |doc| block.call(doc) }
    end

    # Performs a search and pretty prints the results.
    # See Wgit::Database#search for details of the search.
    #
    # @param query [String] The text query to search with.
    # @param whole_sentence [Boolean] Whether multiple words should be searched
    #   for separately.
    # @param limit [Integer] The max number of results to return.
    # @param skip [Integer] The number of DB records to skip.
    # @param sentence_length [Integer] The max length of each result's text
    #   snippet.
    # @yield [doc] Given each search result (Wgit::Document).
    def search_p(query, whole_sentence = false, limit = 10, 
                 skip = 0, sentence_length = 80, &block)
      results = search(query, whole_sentence, limit, skip, &block)
      Wgit::Utils.printf_search_results(results, query, false, sentence_length)
    end

    # Returns statistics about the database.
    #
    # @return [BSON::Document#[]#fetch] Similar to a Hash instance.
    def stats
        @@client.command(:dbStats => 0).documents[0]
    end
  
    # Returns the current size of the database.
    #
    # @return [Integer] The current size of the DB.
    def size
        stats[:dataSize]
    end
  
    ### Update Data ###
  
    # Update a Url or Document object in the DB.
    #
    # @param data [Hash, Enumerable<Hash>] Hash(es) returned from
    #   Wgit::Model.url or Wgit::Model.document.
    # @raise [RuntimeError] If the data is not valid.
    def update(data)
      if data.is_a?(Url)
        update_url(data)
      elsif data.is_a?(Document)
        update_doc(data)
      else
        raise "data is not in the correct format (all Url's or Document's)"
      end
    end

private

    # Return if the write to the DB succeeded or not.
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

    # Insert one or more Url objects into the DB.
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
  
    # Insert one or more Document objects into the DB.
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
  
    # Create/insert one or more Url or Document records into the DB.
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
  
    # Retrieve Url or Document records from the DB.
    def retrieve(collection, query, sort = {}, projection = {}, 
                 limit = 0, skip = 0)
        assert_type(query, Hash)
        @@client[collection.to_sym].find(query).projection(projection)
                                  .skip(skip).limit(limit).sort(sort)
    end

    # Update a Url object in the DB.
    def update_url(url)
        assert_type(url, Url)
        selection = { :url => url }
        url_hash = Wgit::Model.url(url).merge(Wgit::Model.common_update_data)
        update = { "$set" => url_hash }
        _update(true, :urls, selection, update)
    end

    # Update a Document object in the DB.
    def update_doc(doc)
        assert_type(doc, Document)
        selection = { :url => doc.url }
        doc_hash = Wgit::Model.document(doc).merge(Wgit::Model.common_update_data)
        update = { "$set" => doc_hash }
        _update(true, :documents, selection, update)
    end
  
    # Update one or more Url or Document records in the DB.
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
    alias :search_and_format :search_p
  end
end
