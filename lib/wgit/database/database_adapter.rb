# frozen_string_literal: true

require_relative "../assertable"
require_relative "../url"
require_relative "../document"
require_relative "../model"

module Wgit::Database
  # The parent DatabaseAdapter class that should be inherited from when
  # creating an underlying Database adapter implementation class e.g.
  # Wgit::Database::MongoDB.
  #
  # Listed in this class are the methods that an implementer class must
  # implement to work with Wgit. Failure to do so will result in a
  # NotImplementedError being raised.
  #
  # While not required, implementing the method `#search_fields=(fields)` in an
  # adapter class will allow `Wgit::Model.set_search_fields` to call
  # it. This allows the search fields to be set in one method call, from within
  # the Wgit::Model class. See this method's docs for more info.
  #
  # Also listed in this class are common helper methods available to all
  # Database implementer subclasses.
  class DatabaseAdapter
    include Wgit::Assertable

    # The NotImplementedError message that gets raised if an implementor class
    # doesn't implement a method required by Wgit.
    NOT_IMPL_ERR = "The DatabaseAdapter class you're using hasn't \
  implemented this method"

    ###################### START OF INTERFACE METHODS ######################

    # Initializes a DatabaseAdapter instance.
    #
    # The implementor class should establish a DB connection here using the
    # given connection_string, falling back to `ENV['WGIT_CONNECTION_STRING']`.
    # Don't forget to call `super`.
    #
    # @param connection_string [String] The connection string needed to connect
    #   to the database.
    # @raise [StandardError] If a connection string isn't provided, either as a
    #   parameter or via the environment.
    def initialize(connection_string = nil); end

    # Returns the current size of the database.
    #
    # @return [Integer] The current size of the DB.
    def size
      raise NotImplementedError, NOT_IMPL_ERR
    end

    # Searches the database's Documents for the given query. The
    # `Wgit::Model.search_fields` should be searched for matches
    # against the given query. Documents should be sorted starting with the
    # most relevant. Each returned Document should have it's `score` field set
    # for relevance.
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
      raise NotImplementedError, NOT_IMPL_ERR
    end

    # Deletes everything in the urls and documents collections.
    #
    # @return [Integer] The number of deleted records.
    def empty
      raise NotImplementedError, NOT_IMPL_ERR
    end

    # Returns Url records that haven't yet been crawled.
    #
    # @param limit [Integer] The max number of Url's to return. 0 returns all.
    # @param skip [Integer] Skip n amount of Url's.
    # @yield [url] Given each Url object (Wgit::Url) returned from the DB.
    # @return [Array<Wgit::Url>] The uncrawled Urls obtained from the DB.
    def uncrawled_urls(limit: 0, skip: 0)
      raise NotImplementedError, NOT_IMPL_ERR
    end

    # Inserts or updates the object in the database.
    #
    # @param obj [Wgit::Url, Wgit::Document] The obj/record to insert/update.
    # @return [Boolean] True if inserted, false if updated.
    def upsert(obj)
      raise NotImplementedError, NOT_IMPL_ERR
    end

    # Bulk upserts the objects in the database collection.
    # You cannot mix collection objs types, all must be Urls or Documents.
    #
    # @param objs [Array<Wgit::Url>, Array<Wgit::Document>] The objs to be
    #   inserted/updated.
    # @return [Integer] The total number of newly inserted objects.
    def bulk_upsert(objs)
      raise NotImplementedError, NOT_IMPL_ERR
    end

    ###################### END OF INTERFACE METHODS ######################

    private

    # Returns the correct Wgit::Database:Model for the given obj type.
    #
    # @param obj [Wgit::Url, Wgit::Document] The obj to obtain a model for.
    # @return [Hash] The obj model.
    def build_model(obj)
      assert_type(obj, [Wgit::Url, Wgit::Document])

      if obj.is_a?(Wgit::Url)
        Wgit::Model.url(obj)
      else
        Wgit::Model.document(obj)
      end
    end

    # Map each DB hash object into a Wgit::Document. Each Document is yielded
    # if a block is given before returning the mapped Array of Documents.
    def map_documents(doc_hashes)
      doc_hashes.map do |doc|
        doc = Wgit::Document.new(doc)
        yield(doc) if block_given?
        doc
      end
    end

    # Map each DB hash object into a Wgit::Url. Each Url is yielded
    # if a block is given before returning the mapped Array of Urls.
    def map_urls(url_hashes)
      url_hashes.map do |url|
        url = Wgit::Url.new(url)
        yield(url) if block_given?
        url
      end
    end
  end
end
