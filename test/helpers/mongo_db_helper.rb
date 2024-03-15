# frozen_string_literal: true

require_relative 'database_test_data'
require_relative 'database_helper'
require 'mongo'

# Helper class used to manipulate the MongoDB database.
module MongoDBHelper
  include DatabaseHelper

  # Returns the connected Wgit::Database::DatabaseAdapter instance.
  def database_instance
    Wgit::Database::MongoDB.new
  end

  # Deletes everything in the urls and documents collections.
  def empty_db
    db.client[:urls].delete_many({})
    db.client[:documents].delete_many({})
  end

  # Seed an Array of url Hashes into the database.
  def seed_urls(url_hashes)
    db.client[:urls].insert_many(url_hashes)
  rescue StandardError => e
    err_msg = e.respond_to?(:result) ? e.result['writeErrors'] : e.message
    raise "Write to DB failed - remember that both urls and docs won't \
accept duplicate urls. Exception details: #{err_msg}"
  end

  # Seed an Array of document Hashes into the database.
  def seed_docs(doc_hashes)
    db.client[:documents].insert_many(doc_hashes)
  rescue StandardError => e
    err_msg = e.respond_to?(:result) ? e.result['writeErrors'] : e.message
    raise "Write to DB failed - remember that both urls and docs won't \
accept duplicate urls. Exception details: #{err_msg}"
  end

  # Returns if the url_hash/record exists in the DB.
  #
  # Different from Wgit::Database::MongoDB#url? because it asserts the full
  # url_hash, not just the presence of the unique 'url' field.
  def url?(url_hash)
    db.client[:urls].find(url_hash).any?
  end

  # Returns if the doc_hash/record exists in the DB.
  #
  # Different from Wgit::Database::MongoDB#doc? because it asserts the full
  # doc_hash, not just the presence of the unique 'url' field.
  def doc?(doc_hash)
    db.client[:documents].find(doc_hash).any?
  end
end
