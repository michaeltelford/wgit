# frozen_string_literal: true

require_relative '../url'
require_relative '../document'
require_relative '../logger'
require_relative '../assertable'
require_relative 'model'
require 'logger'
require 'mongo'

module Wgit
  # Class providing a DB connection and CRUD operations for the Url and
  # Document collections.
  class Database
    include Assertable

    # The default name of the urls collection.
    URLS_COLLECTION = :urls.freeze

    # The default name of the documents collection.
    DOCUMENTS_COLLECTION = :documents.freeze

    # The default name of the documents collection text search index.
    TEXT_INDEX = 'text_search'

    # The default name of the urls and documents collections unique index.
    UNIQUE_INDEX = 'unique_url'

    # The documents collection default text search index. Use
    # `db.text_index = Wgit::Database::DEFAULT_TEXT_INDEX` to revert changes.
    DEFAULT_TEXT_INDEX = {
      title: 2,
      description: 2,
      keywords: 2,
      text: 1
    }.freeze

    # The connection string for the database.
    attr_reader :connection_string

    # The database client object. Gets set when a connection is established.
    attr_reader :client

    # The documents collection text index, used to search the DB.
    # A custom setter method is also provided for changing the search logic.
    attr_reader :text_index

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
      @text_index = DEFAULT_TEXT_INDEX
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

    ### DDL ###

    # Creates the urls and documents collections if they don't already exist.
    # This method is therefore idempotent.
    #
    # @return [nil] Always returns nil.
    def create_collections
      db.client[URLS_COLLECTION].create rescue nil
      db.client[DOCUMENTS_COLLECTION].create rescue nil

      nil
    end

    # Creates the urls and documents unique 'url' indexes if they don't already
    # exist. This method is therefore idempotent.
    #
    # @return [nil] Always returns nil.
    def create_unique_indexes
      @client[URLS_COLLECTION].indexes.create_one(
        { url: 1 }, name: UNIQUE_INDEX, unique: true
      ) rescue nil

      @client[DOCUMENTS_COLLECTION].indexes.create_one(
        { 'url.url' => 1 }, name: UNIQUE_INDEX, unique: true
      ) rescue nil

      nil
    end

    # Set the documents collection text search index aka the fields to #search.
    # This is labor intensive on large collections so change little and wisely.
    # This method is idempotent in that it will remove the index if it already
    # exists before it creates the new index.
    #
    # @param fields [Array<Symbol>, Hash<Symbol, Integer>] The field names or
    #   the field names and their coresponding search weights.
    # @return [Array<Symbol>, Hash] The passed in value of fields. Use
    #   `#text_index` to get the new index's fields and weights.
    # @raise [StandardError] If fields is of an incorrect type or an error
    #   occurs with the underlying DB client.
    def text_index=(fields)
      # We want to end up with a Hash of fields (Symbols) and their
      # weights (Integers).
      case fields
      when Array # of Strings/Symbols.
        fields = fields.map { |field| [field.to_sym, 1] }
      when Hash  # of Strings/Symbols and Integers.
        fields = fields.map { |field, weight| [field.to_sym, weight.to_i] }
      else
        raise "fields must be an Array or Hash, not a #{fields.class}"
      end

      fields  = fields.to_h
      indexes = @client[DOCUMENTS_COLLECTION].indexes

      indexes.drop_one(TEXT_INDEX) if indexes.get(TEXT_INDEX)
      indexes.create_one(
        fields.map { |field, _| [field, 'text'] }.to_h,
        { name: TEXT_INDEX, weights: fields, background: true }
      )

      @text_index = fields
    end

    ### Create Data ###

    # Insert one or more Url or Document objects into the DB.
    #
    # @param data [Wgit::Url, Wgit::Document, Enumerable<Wgit::Url,
    #   Wgit::Document>] The records to insert/create.
    # @raise [StandardError] If data isn't valid.
    def insert(data)
      data = data.dup # Avoid modifying by reference.
      collection = nil

      if data.respond_to?(:map!)
        data.map! do |obj|
          collection, _, model = get_type_info(obj)
          model
        end
      else
        collection, _, model = get_type_info(data)
        data = model
      end

      create(collection, data)
    end

    # Inserts or updates the object in the database.
    #
    # @param obj [Wgit::Url, Wgit::Document] The obj/record to insert/update.
    # @return [Boolean] True if inserted, false if updated.
    def upsert(obj)
      collection, query, model = get_type_info(obj.dup)
      data_hash = model.merge(Wgit::Model.common_update_data)
      result = @client[collection].replace_one(query, data_hash, upsert: true)

      result.matched_count == 0
    end

    ### Retrieve Data ###

    # Returns all Document records from the DB. Use #search to filter based on
    # the text_index of the collection.
    #
    # All Documents are sorted by date_added ascending, in other words the
    # first doc returned is the first one that was inserted into the DB.
    #
    # @param limit [Integer] The max number of returned records. 0 returns all.
    # @param skip [Integer] Skip n records.
    # @yield [doc] Given each Document object (Wgit::Document) returned from
    #   the DB.
    # @return [Array<Wgit::Document>] The Documents obtained from the DB.
    def docs(limit: 0, skip: 0)
      results = retrieve(DOCUMENTS_COLLECTION, {},
                         sort: { date_added: 1 }, limit: limit, skip: skip)
      return [] if results.count < 1 # results#empty? doesn't exist.

      # results.respond_to? :map! is false so we use map and overwrite the var.
      results = results.map { |doc_hash| Wgit::Document.new(doc_hash) }
      results.each { |doc| yield(doc) } if block_given?

      results
    end

    # Returns all Url records from the DB.
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

      results = retrieve(URLS_COLLECTION, query,
                         sort: sort, limit: limit, skip: skip)
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

      results = retrieve(DOCUMENTS_COLLECTION, query,
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
      @client[URLS_COLLECTION].count
    end

    # Returns the total number of Document records in the DB.
    #
    # @return [Integer] The current number of Document records.
    def num_docs
      @client[DOCUMENTS_COLLECTION].count
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
      query = { url: url }
      retrieve(URLS_COLLECTION, query, limit: 1).any?
    end

    # Returns whether or not a record with the given doc 'url.url' field
    # (which is unique) exists in the database's 'documents' collection.
    #
    # @param doc [Wgit::Document] The Document to search the DB for.
    # @return [Boolean] True if doc exists, otherwise false.
    def doc?(doc)
      assert_type(doc, Wgit::Document)
      query = { 'url.url' => doc.url }
      retrieve(DOCUMENTS_COLLECTION, query, limit: 1).any?
    end

    # Returns if a record exists with the given obj's url.
    #
    # @param obj [Wgit::Url, Wgit::Document] Object containing the url to
    #   search for.
    # @return [Boolean] True if a record exists with the url, false otherwise.
    def exists?(obj)
      obj.is_a?(String) ? url?(obj) : doc?(obj)
    end

    # Returns a record from the database with the matching 'url' field; or nil.
    # Pass either a Wgit::Url or Wgit::Document instance.
    #
    # @param obj [Wgit::Url, Wgit::Document] The record to search the DB for.
    # @return [Wgit::Url, Wgit::Document, nil] The record with the matching
    #   'url' field or nil if no results can be found.
    def get(obj)
      collection, query = get_type_info(obj)

      record = retrieve(collection, query, limit: 1).first
      return nil unless record

      obj.class.new(record)
    end

    ### Update Data ###

    # Update a Url or Document object in the DB.
    #
    # @param obj [Wgit::Url, Wgit::Document] The obj/record to update.
    # @raise [StandardError] If the obj is not valid.
    # @return [Integer] The number of updated records/objects.
    def update(obj)
      collection, query, model = get_type_info(obj.dup)
      data_hash = model.merge(Wgit::Model.common_update_data)

      mutate(collection, query, { '$set' => data_hash })
    end

    ### Delete Data ###

    # Deletes a record from the database with the matching 'url' field.
    # Pass either a Wgit::Url or Wgit::Document instance.
    #
    # @param obj [Wgit::Url, Wgit::Document] The record to search the DB for
    #   and delete.
    # @return [Integer] The number of records deleted - should always be
    #   0 or 1 because urls are unique.
    def delete(obj)
      collection, query = get_type_info(obj)
      @client[collection].delete_one(query).n
    end

    # Deletes everything in the urls collection.
    #
    # @return [Integer] The number of deleted records.
    def clear_urls
      @client[URLS_COLLECTION].delete_many({}).n
    end

    # Deletes everything in the documents collection.
    #
    # @return [Integer] The number of deleted records.
    def clear_docs
      @client[DOCUMENTS_COLLECTION].delete_many({}).n
    end

    # Deletes everything in the urls and documents collections. This will nuke
    # the entire database so yeah... be careful.
    #
    # @return [Integer] The number of deleted records.
    def clear_db
      clear_urls + clear_docs
    end

    private

    # Get the database's type info (collection type, query hash, model) for
    # obj.
    #
    # Raises an error if obj isn't a Wgit::Url or Wgit::Document.
    # Note, that no database calls are made during this method call.
    #
    # @param obj [Wgit::Url, Wgit::Document] The obj to get semantics for.
    # @raise [StandardError] If obj isn't a Wgit::Url or Wgit::Document.
    # @return [Array<Symbol, Hash>] The collection type, query to get
    #   the record/obj from the database (if it exists) and the model of obj.
    def get_type_info(obj)
      case obj
      when Wgit::Url
        collection = URLS_COLLECTION
        query      = { url: obj.to_s }
        model      = Wgit::Model.url(obj)
      when Wgit::Document
        collection = DOCUMENTS_COLLECTION
        query      = { 'url.url' => obj.url.to_s }
        model      = Wgit::Model.document(obj)
      else
        raise "obj must be a Wgit::Url or Wgit::Document, not: #{obj.class}"
      end

      [collection, query, model]
    end

    # Create/insert one or more Url or Document records into the DB.
    #
    # @param collection [Symbol] Either :urls or :documents.
    # @param data [Hash, Array<Hash>] The data to insert.
    # @raise [StandardError] If data type is unsupported or the write fails.
    # @return [Integer] The number of inserted records.
    def create(collection, data)
      assert_types(data, [Hash, Array])

      case data
      when Hash # Single record.
        data.merge!(Wgit::Model.common_insert_data)
        result = @client[collection.to_sym].insert_one(data)
        raise 'DB write (insert) failed' unless write_succeeded?(result)

        result.n
      when Array # Multiple records.
        assert_arr_type(data, Hash)
        data.map! { |hash| hash.merge(Wgit::Model.common_insert_data) }
        result = @client[collection.to_sym].insert_many(data)
        unless write_succeeded?(result, num_writes: data.length)
          raise 'DB write(s) (insert) failed'
        end

        result.inserted_count
      else
        raise 'data must be a Hash or an Array of Hashes'
      end
    end

    # Return if the write to the DB succeeded or not.
    #
    # @param result [Mongo::Collection::View] The write result.
    # @param num_writes [Integer] The number of records written to.
    # @raise [StandardError] If the result type isn't supported.
    # @return [Boolean] True if the write was successful, false otherwise.
    def write_succeeded?(result, num_writes: 1)
      case result
      when Mongo::Operation::Insert::Result # Single create result.
        result.documents.first[:err].nil?
      when Mongo::BulkWrite::Result # Multiple create result.
        result.inserted_count == num_writes
      when Mongo::Operation::Update::Result # Single/multiple update result.
        singleton = (num_writes == 1)
        singleton ? result.documents.first[:err].nil? : result.n == num_writes
      else # Class no longer used, have you upgraded the 'mongo' gem?
        raise "Result class not currently supported: #{result.class}"
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
    # @return [Mongo::Collection::View] The retrieval viewset.
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
    # @param collection [Symbol] Either :urls or :documents.
    # @param query [Hash] The query used for the retrieval before updating.
    # @param update [Hash] The updated/new object.
    # @raise [StandardError] If the update fails.
    # @return [Integer] The number of updated records/objects.
    def mutate(collection, query, update)
      assert_arr_type([query, update], Hash)

      result = @client[collection.to_sym].update_one(query, update)
      raise 'DB write(s) (update) failed' unless write_succeeded?(result)

      result.n
    end

    alias num_objects num_records
    alias clear_db! clear_db
  end
end
