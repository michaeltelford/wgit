# frozen_string_literal: true

require_relative "database_test_data"
require_relative "database_helper"
require "mongo"

# Helper class used to manipulate the InMemory database.
module InMemoryHelper
  include DatabaseHelper

  # Returns the connected InMemory instance.
  def db
    @db ||= Wgit::Database::InMemory.new
  end

  # Deletes everything in the urls and documents collections.
  def empty_db
    # Normally you shouldn't call the adapter class but this just sets new
    # concurrent arrays to the instance vars, so can't really go wrong.
    db.send(:initialize_store)
  end

  # Seed an Array of url Hashes into the database.
  def seed_urls(url_hashes)
    url_hashes.each { |url_h| db.urls << url_h }
  end

  # Seed an Array of document Hashes into the database.
  def seed_docs(doc_hashes)
    doc_hashes.each { |doc_h| db.docs << doc_h }
  end

  # Returns if the url_hash/record exists in the database.
  def url?(url_hash)
    db.urls.any? { |url| url == url_hash }
  end

  # Returns if the doc_hash/record exists in the database.
  def doc?(doc_hash)
    db.docs.any? { |doc| doc == doc_hash }
  end
end
