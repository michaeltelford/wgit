require_relative '../utils'

module Wgit

  # @author Michael Telford
  # Module containing the DB data model structure.
  module Model
      def self.url(url)
          raise "url must respond to to_h" unless url.respond_to?(:to_h)
          url.to_h
      end
    
      def self.document(doc)
          raise "doc must respond to to_h" unless doc.respond_to?(:to_h)
          doc.to_h(false)
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
