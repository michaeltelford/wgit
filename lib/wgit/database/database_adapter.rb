# frozen_string_literal: true

require_relative '../url'
require_relative '../document'
require_relative '../logger'
require_relative '../assertable'
require_relative 'model'
require 'logger'
require 'mongo'

module Wgit
  # Module providing a Database connection and CRUD operations for the Url and
  # Document collections.
  module Database
    # Database adapter class for inheriting from by underlying implementation
    # classes. This class provides a way to include common functionality and
    # also outlines an interface for Database adapters to implement.
    # Implementing this interface ensures compatibility with the rest of Wgit.
    class DatabaseAdapter
      include Wgit::Assertable

      NOT_IMPL_ERR = "The DatabaseAdapter class you're using hasn't \
implemented this method"

      # Initializes a DatabaseAdapter instance.
      # The implementor class should establish a DB connection here...
      def initialize; end

      # Returns the current size of the database.
      #
      # @return [Integer] The current size of the DB.
      def size
        raise NotImplementedError, NOT_IMPL_ERR
      end

      # Searches the database's Documents for the given query.
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

      # Returned Url records that haven't yet been crawled.
      #
      # @param limit [Integer] The max number of Url's to return. 0 returns all.
      # @param skip [Integer] Skip n amount of Url's.
      # @yield [url] Given each Url object (Wgit::Url) returned from the DB.
      # @return [Array<Wgit::Url>] The uncrawled Urls obtained from the DB.
      def uncrawled_urls(limit: 0, skip: 0, &block)
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
      # @return [Integer] The total number of upserted objects.
      def bulk_upsert(objs)
        raise NotImplementedError, NOT_IMPL_ERR
      end
    end
  end
end
