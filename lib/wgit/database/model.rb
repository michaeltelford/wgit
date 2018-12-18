require_relative '../utils'

module Wgit

  # Module containing the database (DB) data model structure.
  module Model
      
    # The data model for a Wgit::Url.
    #
    # @param url [Wgit::Url] The URL DB record.
    # @return [Hash] The URL model ready for DB insertion.
    def self.url(url)
      raise "url must respond_to? to_h" unless url.respond_to?(:to_h)
      model = url.to_h
      Wgit::Utils.remove_non_bson_types(model)
    end
  
    # The data model for a Wgit::Document.
    #
    # @param doc [Wgit::Document] The Document DB record.
    # @return [Hash] The Document model ready for DB insertion.
    def self.document(doc)
      raise "doc must respond_to? to_h" unless doc.respond_to?(:to_h)
      model = doc.to_h(false)
      Wgit::Utils.remove_non_bson_types(model)
    end
  
    # Default fields when inserting a record into the DB.
    #
    # @return [Hash] Containing common insertion fields for all models.
    def self.common_insert_data
      {
        date_added:     Wgit::Utils.time_stamp,
        date_modified:  Wgit::Utils.time_stamp,
      }
    end
  
    # Default fields when updating a record in the DB.
    #
    # @return [Hash] Containing common update fields for all models.
    def self.common_update_data
      {
        date_modified: Wgit::Utils.time_stamp,
      }
    end
  end
end
