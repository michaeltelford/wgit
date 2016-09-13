require_relative '../utils'

module Wgit

  # @author Michael Telford
  # Module containing the DB data model structure.
  module Model
      def self.url(url)
          raise "url must respond to to_h" unless url.respond_to?(:to_h)
          model = url.to_h
          Wgit::Utils.remove_non_bson_types(model)
      end
    
      def self.document(doc)
          raise "doc must respond to to_h" unless doc.respond_to?(:to_h)
          model = doc.to_h(false)
          Wgit::Utils.remove_non_bson_types(model)
      end
    
      def self.common_insert_data
          {
              :date_added     => Wgit::Utils.time_stamp,
              :date_modified  => Wgit::Utils.time_stamp,
          }
      end
    
      def self.common_update_data
          {
              :date_modified  => Wgit::Utils.time_stamp,
          }
      end
  end
end
