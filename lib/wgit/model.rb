# frozen_string_literal: true

require_relative "./utils"

module Wgit
  # Module used to build the Database collection objects, forming a data model.
  # The models produced are Hash like and therefore DB agnostic. Each model
  # will contain a unique field used for searching and avoiding duplicates,
  # this is typically a `url` field. Also contained in the model are the
  # search fields used in Database and Document #search calls.
  module Model
    # The default search fields used in Database and Document #search calls.
    # The number of matches for each field is multiplied by the field weight,
    # the total is the search score, used to sort the search results.
    # Call Wgit::Model.set_default_search_fields` to revert to default.
    DEFAULT_SEARCH_FIELDS = {
      title: 2,
      description: 2,
      keywords: 2,
      text: 1
    }.freeze

    # The search fields used in Database and Document #search calls.
    # The number of matches for each field is multiplied by the field weight,
    # the total is the search score, used to sort the search results.
    # Call Wgit::Model.set_default_search_fields` to revert to default.
    @search_fields = DEFAULT_SEARCH_FIELDS

    # Whether or not to include the Document#html in the #document model.
    @include_doc_html = false

    # Whether or not to include the Document#score in the #document model.
    @include_doc_score = false

    class << self
      # The search fields used in Database and Document #search calls.
      # A custom setter method is also provided for changing these fields.
      attr_reader :search_fields

      # Whether or not to include the Document#html in the #document model.
      attr_accessor :include_doc_html

      # Whether or not to include the Document#score in the #document model.
      attr_accessor :include_doc_score
    end

    # Sets the search fields used in Database and Document #search calls.
    #
    # You can pass the fields as an Array of Symbols which gives each field a
    # weight of 1 meaning all fields are considered of equal value. Or you can
    # pass a Hash of Symbol => Int and specify the weights yourself, allowing
    # you to customise the search rankings.
    #
    # Use like:
    # ```
    # Wgit::Model.set_search_fields [:title, :text], db
    # => { title: 1, text: 1 }
    # Wgit::Model.set_search_fields {title: 2, text: 1}, db
    # => { title: 2, text: 1 }
    # ```
    #
    # If the given db (database) param responds to #search_fields= then it will
    # be called and given the fields to set. This should perform whatever the
    # database adapter needs in order to search using the given fields e.g.
    # creating a search index. Calling the DB enables the search_fields to be
    # set globally within Wgit by one method call, this one.
    #
    # @param fields [Array<Symbol>, Hash<Symbol, Integer>] The field names or
    #   the field names with their coresponding search weights.
    # @param db [Wgit::Database::DatabaseAdapter] A connected db instance. If
    #   db responds to #search_fields=, it will be called and given the fields.
    # @raise [StandardError] If fields is of an incorrect type.
    # @return [Hash<Symbol, Integer>] The fields and their weights.
    def self.set_search_fields(fields, db = nil)
      # We need a Hash of fields => weights (Symbols => Integers).
      case fields
      when Array # of Strings/Symbols.
        fields = fields.map { |field| [field.to_sym, 1] }
      when Hash  # of Strings/Symbols and Integers.
        fields = fields.map { |field, weight| [field.to_sym, weight.to_i] }
      else
        raise "fields must be an Array or Hash, not a #{fields.class}"
      end

      @search_fields = fields.to_h
      db.search_fields = @search_fields if db.respond_to?(:search_fields=)

      @search_fields
    end

    # Sets the search fields used in Database and Document #search calls.
    #
    # If the given db (database) param responds to #search_fields= then it will
    # be called and given the fields to set. This should perform whatever the
    # database adapter needs in order to search using the given fields e.g.
    # creating a search index. Calling the DB enables the search_fields to be
    # set globally within Wgit by one method call, this one.
    #
    # @param db [Wgit::Database::DatabaseAdapter] A connected db instance. If
    #   db responds to #search_fields=, it will be called and given the fields.
    # @return [Hash<Symbol, Integer>] The fields and their weights.
    def self.set_default_search_fields(db = nil)
      set_search_fields(DEFAULT_SEARCH_FIELDS, db)
    end

    # The data model for a Wgit::Url collection object and for an embedded
    # 'url' inside a Wgit::Document collection object.
    #
    # The unique field for this model is `model['url']`.
    #
    # @param url [Wgit::Url] The Url data object.
    # @return [Hash] The URL model ready for DB insertion.
    def self.url(url)
      raise "url must respond_to? :to_h" unless url.respond_to?(:to_h)

      model = url.to_h
      select_bson_types(model)
    end

    # The data model for a Wgit::Document collection object.
    #
    # The unique field for this model is `model['url']['url']`.
    #
    # @param doc [Wgit::Document] The Document data object.
    # @return [Hash] The Document model ready for DB insertion.
    def self.document(doc)
      raise "doc must respond_to? :to_h" unless doc.respond_to?(:to_h)

      model = doc.to_h(
        include_html: @include_doc_html, include_score: @include_doc_score
      )
      model["url"] = url(doc.url) # Expand Url String into full object.

      select_bson_types(model)
    end

    # Common fields when inserting a record into the DB.
    #
    # @return [Hash] Insertion fields common to all models.
    def self.common_insert_data
      {
        date_added:    Wgit::Utils.time_stamp,
        date_modified: Wgit::Utils.time_stamp
      }
    end

    # Common fields when updating a record in the DB.
    #
    # @return [Hash] Update fields common to all models.
    def self.common_update_data
      {
        date_modified: Wgit::Utils.time_stamp
      }
    end

    # Returns the model having removed non bson types (for use with MongoDB).
    #
    # @param model_hash [Hash] The model Hash to sanitize.
    # @return [Hash] The model Hash with non bson types removed.
    def self.select_bson_types(model_hash)
      model_hash.select { |_k, v| v.respond_to?(:bson_type) }
    end
  end
end
