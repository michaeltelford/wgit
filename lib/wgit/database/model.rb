# frozen_string_literal: true

require_relative '../utils'

module Wgit
  # Module used to build the database collection objects, forming a data model.
  module Model
    # The data model for a Wgit::Url collection object and for an embedded
    # 'url' inside a Wgit::Document collection object.
    #
    # @param url [Wgit::Url] The Url data object.
    # @return [Hash] The URL model ready for DB insertion.
    def self.url(url)
      raise 'url must respond_to? :to_h' unless url.respond_to?(:to_h)

      model = url.to_h
      Wgit::Utils.remove_non_bson_types(model)
    end

    # The data model for a Wgit::Document collection object.
    #
    # @param doc [Wgit::Document] The Document data object.
    # @return [Hash] The Document model ready for DB insertion.
    def self.document(doc)
      raise 'doc must respond_to? :to_h' unless doc.respond_to?(:to_h)

      model = doc.to_h(include_html: false)
      model['url'] = self.url(doc.url) # Expand Url String into full object.

      Wgit::Utils.remove_non_bson_types(model)
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
  end
end
