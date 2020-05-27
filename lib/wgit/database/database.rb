# frozen_string_literal: true

require_relative '../url'
require_relative '../document'
require_relative '../logger'
require_relative '../assertable'
require_relative 'model'
require 'logger'
require 'mongo'

module Wgit
  # Class modeling a DB connection and CRUD operations for the Url and Document
  # collections.
  class Database
    include Assertable

    # The connection string for the database.
    attr_reader :connection_string

    # The database client object. Gets set when a connection is established.
    attr_reader :client

    # Initializes a connected database client using the provided
    # connection_string or ENV['WGIT_CONNECTION_STRING'].
    #
    # @param connection_string [String] The connection string needed to connect
    #   to the database.
    # @raise [StandardError] If a connection string isn't provided, either as a
    #   parameter or via the environment.
    def initialize(connection_string = nil)
      connection_string ||= ENV['WGIT_CONNECTION_STRING']
      raise "connection_string and ENV['WGIT_CONNECTION_STRING'] are nil" \
      unless connection_string

      @client = Database.establish_connection(connection_string)
      @connection_string = connection_string
    end

    # A class alias for Database.new.
    #
    # @param connection_string [String] The connection string needed to connect
    #   to the database.
    # @raise [StandardError] If a connection string isn't provided, either as a
    #   parameter or via the environment.
    # @return [Wgit::Database] The connected database client.
    def self.connect(connection_string = nil)
      new(connection_string)
    end

    # Initializes a connected database client using the connection string.
    #
    # @param connection_string [String] The connection string needed to connect
    #   to the database.
    # @raise [StandardError] If a connection cannot be established.
    # @return [Mong::Client] The connected MongoDB client.
    def self.establish_connection(connection_string)
      # Only log for error (and more severe) scenarios.
      Mongo::Logger.logger          = Wgit.logger.clone
      Mongo::Logger.logger.progname = 'mongo'
      Mongo::Logger.logger.level    = Logger::ERROR

      # Connects to the database here.
      Mongo::Client.new(connection_string)
    end

    ### Create Data ###

    # Insert one or more Url or Document objects into the DB.
    #
    # @param data [Wgit::Url, Wgit::Document, Enumerable<Wgit::Url,
    #   Wgit::Document>] Hash(es) returned from Wgit::Model.url or
    #   Wgit::Model.document.
    # @raise [StandardError] If data isn't valid.
    def insert(data)
      data = data.dup # Avoid modifying by reference.
      type = data.is_a?(Enumerable) ? data.first : data

      case type
      when Wgit::Url
        insert_urls(data)
      when Wgit::Document
        insert_docs(data)
      else
        raise "Unsupported type - #{data.class}: #{data}"
      end
    end

    ### Retrieve Data ###

    # Returns Url records from the DB.
    #
    # All Urls are sorted by date_added ascending, in other words the first url
    # returned is the first one that was inserted into the DB.
    #
    # @param crawled [Boolean] Filter by Url#crawled value. nil returns all.
    # @param limit [Integer] The max number of Url's to return. 0 returns all.
    # @param skip [Integer] Skip n amount of Url's.
    # @yield [url] Given each Url object (Wgit::Url) returned from the DB.
    # @return [Array<Wgit::Url>] The Urls obtained from the DB.
    def urls(crawled: nil, limit: 0, skip: 0)
      query = crawled.nil? ? {} : { crawled: crawled }
      sort = { date_added: 1 }

      results = retrieve(:urls, query,
                         sort: sort, projection: {},
                         limit: limit, skip: skip)
      return [] if results.count < 1 # results#empty? doesn't exist.

      # results.respond_to? :map! is false so we use map and overwrite the var.
      results = results.map { |url_doc| Wgit::Url.new(url_doc) }
      results.each { |url| yield(url) } if block_given?

      results
    end

    # Returns Url records that have been crawled.
    #
    # @param limit [Integer] The max number of Url's to return. 0 returns all.
    # @param skip [Integer] Skip n amount of Url's.
    # @yield [url] Given each Url object (Wgit::Url) returned from the DB.
    # @return [Array<Wgit::Url>] The crawled Urls obtained from the DB.
    def crawled_urls(limit: 0, skip: 0, &block)
      urls(crawled: true, limit: limit, skip: skip, &block)
    end

    # Returned Url records that haven't yet been crawled.
    #
    # @param limit [Integer] The max number of Url's to return. 0 returns all.
    # @param skip [Integer] Skip n amount of Url's.
    # @yield [url] Given each Url object (Wgit::Url) returned from the DB.
    # @return [Array<Wgit::Url>] The uncrawled Urls obtained from the DB.
    def uncrawled_urls(limit: 0, skip: 0, &block)
      urls(crawled: false, limit: limit, skip: skip, &block)
    end

    # Searches the database's Documents for the given query.
    #
    # The searched fields are decided by the text index setup on the
    # documents collection. Currently we search against the following fields:
    # "author", "keywords", "title" and "text" by default.
    #
    # The MongoDB search algorithm ranks/sorts the results in order (highest
    # first) based on each document's "textScore" (which records the number of
    # query hits). The "textScore" is then stored in each Document result
    # object for use elsewhere if needed; accessed via Wgit::Document#score.
    #
    # @param query [String] The text query to search with.
    # @param case_sensitive [Boolean] Whether character case must match.
    # @param whole_sentence [Boolean] Whether multiple words should be searched
    #   for separately.
    # @param limit [Integer] The max number of results to return.
    # @param skip [Integer] The number of results to skip.
    # @yield [doc] Given each search result (Wgit::Document) returned from the
    #   DB.
    # @return [Array<Wgit::Document>] The search results obtained from the DB.
    def search(
      query, case_sensitive: false, whole_sentence: true, limit: 10, skip: 0
    )
      query = query.to_s.strip
      query.replace('"' + query + '"') if whole_sentence

      # Sort based on the most search hits (aka "textScore").
      # We use the sort_proj hash as both a sort and a projection below.
      sort_proj = { score: { :$meta => 'textScore' } }
      query = { :$text => {
        :$search => query,
        :$caseSensitive => case_sensitive
      } }

      results = retrieve(:documents, query,
                         sort: sort_proj, projection: sort_proj,
                         limit: limit, skip: skip)
      return [] if results.count < 1 # respond_to? :empty? == false

      # results.respond_to? :map! is false so we use map and overwrite the var.
      results = results.map do |mongo_doc|
        doc = Wgit::Document.new(mongo_doc)
        yield(doc) if block_given?
        doc
      end

      results
    end

    # Searches the database's Documents for the given query and then searches
    # each result in turn using `doc.search!`. This method is therefore the
    # equivalent of calling `Wgit::Database#search` and then
    # `Wgit::Document#search!` in turn. See their documentation for more info.
    #
    # @param query [String] The text query to search with.
    # @param case_sensitive [Boolean] Whether character case must match.
    # @param whole_sentence [Boolean] Whether multiple words should be searched
    #   for separately.
    # @param limit [Integer] The max number of results to return.
    # @param skip [Integer] The number of results to skip.
    # @param sentence_limit [Integer] The max length of each search result
    #   sentence.
    # @yield [doc] Given each search result (Wgit::Document) returned from the
    #   DB having called `doc.search!(query)`.
    # @return [Array<Wgit::Document>] The search results obtained from the DB
    #   having called `doc.search!(query)`.
    def search!(
      query, case_sensitive: false, whole_sentence: true,
      limit: 10, skip: 0, sentence_limit: 80
    )
      results = search(
        query,
        case_sensitive: case_sensitive,
        whole_sentence: whole_sentence,
        limit: limit,
        skip: skip
      )

      results.each do |doc|
        doc.search!(
          query,
          case_sensitive: case_sensitive,
          whole_sentence: whole_sentence,
          sentence_limit: sentence_limit
        )
        yield(doc) if block_given?
      end

      results
    end

    # Returns statistics about the database.
    #
    # @return [BSON::Document#[]#fetch] Similar to a Hash instance.
    def stats
      @client.command(dbStats: 0).documents[0]
    end

    # Returns the current size of the database.
    #
    # @return [Integer] The current size of the DB.
    def size
      stats[:dataSize]
    end

    # Returns the total number of URL records in the DB.
    #
    # @return [Integer] The current number of URL records.
    def num_urls
      @client[:urls].count
    end

    # Returns the total number of Document records in the DB.
    #
    # @return [Integer] The current number of Document records.
    def num_docs
      @client[:documents].count
    end

    # Returns the total number of records (urls + docs) in the DB.
    #
    # @return [Integer] The current number of URL and Document records.
    def num_records
      num_urls + num_docs
    end

    # Returns whether or not a record with the given 'url' field (which is
    # unique) exists in the database's 'urls' collection.
    #
    # @param url [Wgit::Url] The Url to search the DB for.
    # @return [Boolean] True if url exists, otherwise false.
    def url?(url)
      assert_type(url, String) # This includes Wgit::Url's.
      hash = { 'url' => url }
      @client[:urls].find(hash).any?
    end

    # Returns whether or not a record with the given doc 'url.url' field
    # (which is unique) exists in the database's 'documents' collection.
    #
    # @param doc [Wgit::Document] The Document to search the DB for.
    # @return [Boolean] True if doc exists, otherwise false.
    def doc?(doc)
      assert_type(doc, Wgit::Document)
      hash = { 'url.url' => doc.url }
      @client[:documents].find(hash).any?
    end

    ### Update Data ###

    # Update a Url or Document object in the DB.
    #
    # @param data [Wgit::Url, Wgit::Document] The data to update.
    # @raise [StandardError] If the data is not valid.
    def update(data)
      data = data.dup # Avoid modifying by reference.

      case data
      when Wgit::Url
        update_url(data)
      when Wgit::Document
        update_doc(data)
      else
        raise "Unsupported type - #{data.class}: #{data}"
      end
    end

    ### Delete Data ###

    # Deletes everything in the urls collection.
    #
    # @return [Integer] The number of deleted records.
    def clear_urls
      @client[:urls].delete_many({}).n
    end

    # Deletes everything in the documents collection.
    #
    # @return [Integer] The number of deleted records.
    def clear_docs
      @client[:documents].delete_many({}).n
    end

    # Deletes everything in the urls and documents collections. This will nuke
    # the entire database so yeah... be careful.
    #
    # @return [Integer] The number of deleted records.
    def clear_db
      clear_urls + clear_docs
    end

    protected

    # Insert one or more Url objects into the DB.
    #
    # @param data [Wgit::Url, Array<Wgit::Url>] One or more Urls to insert.
    # @raise [StandardError] If data type isn't supported.
    # @return [Integer] The number of inserted Urls.
    def insert_urls(data)
      if data.respond_to?(:map!)
        assert_arr_type(data, Wgit::Url)
        data.map! { |url| Wgit::Model.url(url) }
      else
        assert_type(data, Wgit::Url)
        data = Wgit::Model.url(data)
      end

      create(:urls, data)
    end

    # Insert one or more Document objects into the DB.
    #
    # @param data [Wgit::Document, Array<Wgit::Document>] One or more Documents
    #   to insert.
    # @raise [StandardError] If data type isn't supported.
    # @return [Integer] The number of inserted Documents.
    def insert_docs(data)
      if data.respond_to?(:map!)
        assert_arr_type(data, Wgit::Document)
        data.map! { |doc| Wgit::Model.document(doc) }
      else
        assert_types(data, Wgit::Document)
        data = Wgit::Model.document(data)
      end

      create(:documents, data)
    end

    # Update a Url record in the DB.
    #
    # @param url [Wgit::Url] The Url to update.
    # @return [Integer] The number of updated records.
    def update_url(url)
      assert_type(url, Wgit::Url)
      selection = { url: url }
      url_hash = Wgit::Model.url(url).merge(Wgit::Model.common_update_data)
      update = { '$set' => url_hash }
      mutate(true, :urls, selection, update)
    end

    # Update a Document record in the DB.
    #
    # @param doc [Wgit::Document] The Document to update.
    # @return [Integer] The number of updated records.
    def update_doc(doc)
      assert_type(doc, Wgit::Document)
      selection = { 'url.url' => doc.url }
      doc_hash = Wgit::Model.document(doc).merge(Wgit::Model.common_update_data)
      update = { '$set' => doc_hash }
      mutate(true, :documents, selection, update)
    end

    private

    # Return if the write to the DB succeeded or not.
    #
    # @param result [Mongo::Object] The operation result.
    # @param records [Integer] The number of records written to.
    # @param multi [Boolean] Whether several records are being written to.
    # @raise [StandardError] If the result type isn't supported.
    # @return [Boolean] True if the write was successful, false otherwise.
    def write_succeeded?(result, records: 1, multi: false)
      case result
      # Single create result.
      when Mongo::Operation::Insert::Result
        result.documents.first[:err].nil?
      # Multiple create result.
      when Mongo::BulkWrite::Result
        result.inserted_count == records
      # Single and multiple update result.
      when Mongo::Operation::Update::Result
        multi ? result.n == records : result.documents.first[:err].nil?
      # Class no longer used, have you upgraded the 'mongo' gem?
      else
        raise "Result class not currently supported: #{result.class}"
      end
    end

    # Create/insert one or more Url or Document records into the DB.
    #
    # @param collection [Symbol] Either :urls or :documents.
    # @param data [Hash, Array<Hash>] The data to insert.
    # @raise [StandardError] If data type is unsupported or the write fails.
    # @return [Integer] The number of inserted records.
    def create(collection, data)
      assert_types(data, [Hash, Array])

      # Single doc.
      case data
      when Hash
        data.merge!(Wgit::Model.common_insert_data)
        result = @client[collection.to_sym].insert_one(data)
        raise 'DB write (insert) failed' unless write_succeeded?(result)

        result.n
      # Multiple docs.
      when Array
        assert_arr_type(data, Hash)
        data.map! { |hash| hash.merge(Wgit::Model.common_insert_data) }
        result = @client[collection.to_sym].insert_many(data)
        raise 'DB write(s) (insert) failed' unless write_succeeded?(
          result, records: data.length
        )

        result.inserted_count
      else
        raise 'data must be a Hash or an Array of Hashes'
      end
    end

    # Retrieve Url or Document records from the DB.
    #
    # @param collection [Symbol] Either :urls or :documents.
    # @param query [Hash] The query used for the retrieval.
    # @param sort [Hash] The sort to use.
    # @param projection [Hash] The projection to use.
    # @param limit [Integer] The limit to use.
    # @param skip [Integer] The skip to use.
    # @raise [StandardError] If query type isn't valid.
    # @return [Mongo::Object] The Mongo client operation result.
    def retrieve(collection, query,
                 sort: {}, projection: {},
                 limit: 0, skip: 0)
      assert_type(query, Hash)
      @client[collection.to_sym].find(query).projection(projection)
                                .skip(skip).limit(limit).sort(sort)
    end

    # Mutate/update one or more Url or Document records in the DB.
    #
    # This method expects Model.common_update_data to have been merged in
    # already by the calling method.
    #
    # @param single [Boolean] Wether or not a single record is being updated.
    # @param collection [Symbol] Either :urls or :documents.
    def mutate(single, collection, selection, update)
      assert_arr_type([selection, update], Hash)

      collection = collection.to_sym
      unless %i[urls documents].include?(collection)
        raise "Invalid collection: #{collection}"
      end

      result = if single
                 @client[collection].update_one(selection, update)
               else
                 @client[collection].update_many(selection, update)
               end
      raise 'DB write (update) failed' unless write_succeeded?(result)

      result.n
    end

    alias count       size
    alias length      size
    alias document?   doc?
    alias insert_url  insert_urls
    alias insert_doc  insert_docs
    alias num_objects num_records
  end
end
