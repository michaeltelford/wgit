require_relative "../../utils"
require_relative "../../url"
require_relative "../../document"
require_relative "../../model"
require_relative "../database_adapter"

module Wgit::Database
  # Database implementer class for in-memory (RAM) storage. This DB is mainly used
  # for testing and experimenting with. This DB is thread safe.
  class InMemory < DatabaseAdapter
    # Initializes a thread safe InMemory Database instance.
    #
    # @param connection_string [String] Not used but needed to adhere to the
    #   DatabaseAdapter interface.
    def initialize(connection_string = nil)
      # Inits @urls and @docs vars.
      initialize_store

      super
    end

    # Overrides String#inspect to display collection sizes.
    #
    # @return [String] A short textual representation of this object.
    def inspect
      "#<Wgit::Database::InMemory num_urls=#{@urls.size} \
num_docs=#{@docs.size} size=#{size}>"
    end

    # The Wgit::Url's collection stored as an in-memory Concurrent::Array.
    def urls(&block)
      map_urls(@urls, &block)
    end

    # The Wgit::Document's collection stored as an in-memory Concurrent::Array.
    def docs(&block)
      map_documents(@docs, &block)
    end

    # The raw url Hashes, not mapped into their corresponding Wgit objects.
    def url_hashes
      @urls
    end

    # The raw doc Hashes, not mapped into their corresponding Wgit objects.
    def doc_hashes
      @docs
    end

    # Returns the current size of the in-memory database.
    # An empty database will return a size of 4 because there are 4 bytes in
    # two empty arrays (urls and docs collections).
    #
    # @return [Integer] The current size of the in-memory DB.
    def size
      @urls.to_s.size + @docs.to_s.size
    end

    # Searches the database's Document#text for the given query. The returned
    # Documents are sorted for relevance, starting with the most relevant. Each
    # Document's #score value will be set accordingly.
    #
    # @param query [Regexp, #to_s] The regex or text value to search each
    #   document's @text for.
    # @param case_sensitive [Boolean] Whether character case must match.
    # @param whole_sentence [Boolean] Whether multiple words should be searched
    #   for separately.
    # @param limit [Integer] The max number of results to return.
    # @param skip [Integer] The number of results to skip.
    # @yield [doc] Given each search result (Wgit::Document) returned from the
    #   DB.
    # @return [Array<Wgit::Document>] The search results obtained from the DB.
    def search(
      query, case_sensitive: false, whole_sentence: true,
      limit: 10, skip: 0, &block
    )
      regex = Wgit::Utils.build_search_regex(
        query, case_sensitive:, whole_sentence:)

      # Search the Wgit::Document's, not the raw Hashes.
      results = docs.select do |doc|
        score = 0
        doc.search(regex, case_sensitive:, whole_sentence:) do |results_hash|
          score = results_hash.values.sum
        end
        next false if score.zero?

        doc.instance_variable_set :@score, score
        true
      end

      return [] if results.empty?

      results = results.sort_by { |doc| -doc.score }

      results = results[skip..]
      return [] unless results

      results = results[0...limit] if limit.positive?
      results.each(&block) if block_given?

      results
    end

    # Deletes everything in the urls and documents collections.
    #
    # @return [Integer] The number of deleted records.
    def empty
      previous_size = @urls.size + @docs.size
      initialize_store

      previous_size
    end

    # Returns Url records that haven't yet been crawled.
    #
    # @param limit [Integer] The max number of Url's to return. 0 returns all.
    # @param skip [Integer] Skip n amount of Url's.
    # @yield [url] Given each Url object (Wgit::Url) returned from the DB.
    # @return [Array<Wgit::Url>] The uncrawled Urls obtained from the DB.
    def uncrawled_urls(limit: 0, skip: 0, &block)
      uncrawled = @urls.reject { |url| url["crawled"] }
      uncrawled = uncrawled[skip..]
      return [] unless uncrawled

      uncrawled = uncrawled[0...limit] if limit.positive?
      map_urls(uncrawled, &block)
    end

    # Inserts or updates the object in the in-memory database.
    #
    # @param obj [Wgit::Url, Wgit::Document] The obj/record to insert/update.
    # @return [Boolean] True if inserted, false if updated.
    def upsert(obj)
      collection, index, model = get_model_info(obj)

      if index
        collection[index] = model
        false
      else
        collection << model
        true
      end
    end

    # Bulk upserts the objects in the in-memory database collection.
    # You cannot mix collection objs types, all must be Urls or Documents.
    #
    # @param objs [Array<Wgit::Url>, Array<Wgit::Document>] The objs to be
    #   inserted/updated.
    # @return [Integer] The total number of newly inserted objects.
    def bulk_upsert(objs)
      assert_common_arr_types(objs, [Wgit::Url, Wgit::Document])

      objs.reduce(0) do |inserted, obj|
        inserted += 1 if upsert(obj)
        inserted
      end
    end

    private

    # Creates a new Concurrent::Array for each collection.
    def initialize_store
      @urls = Concurrent::Array.new
      @docs = Concurrent::Array.new
    end

    # Get the database's model info (collection type, index, model) for
    # obj.
    #
    # Use like:
    # ```
    # collection, index, model = get_model_info(obj)
    # ```
    #
    # Raises an error if obj isn't a Wgit::Url or Wgit::Document.
    #
    # @param obj [Wgit::Url, Wgit::Document] The obj to get semantics for.
    # @raise [StandardError] If obj isn't a Wgit::Url or Wgit::Document.
    # @return [Array<Symbol, Hash>] The collection type, the obj's index (if in
    #   the collection, nil otherwise) and the Wgit::Model of obj.
    def get_model_info(obj)
      obj = obj.dup

      case obj
      when Wgit::Url
        key        = obj.to_s
        collection = @urls
        index      = @urls.index { |url| url["url"] == key }
        model      = build_model(obj)
      when Wgit::Document
        key        = obj.url.to_s
        collection = @docs
        index      = @docs.index { |doc| doc["url"]&.[]("url") == key }
        model      = build_model(obj)
      else
        raise "obj must be a Wgit::Url or Wgit::Document, not: #{obj.class}"
      end

      [collection, index, model]
    end
  end
end
