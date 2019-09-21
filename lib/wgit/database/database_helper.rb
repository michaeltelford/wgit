# frozen_string_literal: true

require_relative 'database_dev_data'
require 'mongo'

module Wgit
  # Helper class used to manipulate the database.
  #
  # Used in testing and development. This module isn't packaged in the gem and
  # is for devs (via the development console) and tests (setup and assertions)
  # only.
  module DatabaseHelper
    # A connection to the database is established when this module is included.
    def self.included(_base)
      connection_string = ENV.fetch('WGIT_CONNECTION_STRING')
      @@client ||= Database.establish_connection(connection_string)

      @@urls = []
      @@docs = []
    end

    # Returns the number of deleted records.
    def clear_urls
      @@client[:urls].delete_many({}).n
    end

    # Returns the number of deleted records.
    def clear_docs
      @@client[:documents].delete_many({}).n
    end

    # Returns the number of deleted records.
    def clear_db
      clear_urls + clear_docs
    end

    # Seed what's in the block, comprising of url and doc method calls
    # (in this module). If anything other than a hash is given then the default
    # hash is used. An integer can be used to specify how many of default
    # objects should be seeded; defaults to 1.
    #
    # Returns the number of seeded/inserted documents in the DB.
    #
    # Code example:
    #   seed do
    #     url(url: "http://www.google.co.uk")
    #     doc(url: "https://www.myserver.org", html: "<html></html>")
    #     url 3   # Seeds 3 of the default url records.
    #     doc     # Seeds 1 of the default doc records.
    #   end
    def seed(&block)
      raise 'Must provide a block' unless block_given?

      @@urls.clear
      @@docs.clear

      # &block populates the @@urls and @@docs arrays.
      instance_eval(&block)

      begin
        @@client[:urls].insert_many(@@urls)
        @@client[:documents].insert_many(@@docs)

        @@urls.count + @@docs.count
      rescue StandardError => e
        err_msg = e.respond_to?(:result) ? e.result['writeErrors'] : e.message
        raise "Write to DB failed - remember that both urls and docs won't \
accept duplicate urls. Exception details: #{err_msg}"
      end
    end

    # Return if the url_hash/record exists in the DB.
    # Different from Wgit::Database#url? because it asserts the full url_hash.
    def url?(url_hash)
      @@client[:urls].find(url_hash).any?
    end

    # Return if the doc_hash/record exists in the DB.
    # Different from Wgit::Database#doc? because it asserts the full doc_hash.
    def doc?(doc_hash)
      @@client[:documents].find(doc_hash).any?
    end

    # Helper method which crawls a url storing its markup in the database.
    def index_page(url, insert_externals: true)
      Wgit.index_page(url, insert_externals: insert_externals)
    end

    # Helper method which takes a url and recursively indexes the site storing
    # the markup in the database. Use sensible url's, not www.amazon.com etc.
    def index_site(url, insert_externals: true)
      Wgit.index_site(url, insert_externals: insert_externals)
    end

    # Searches the database's Document collection for the given query, formats
    # and pretty prints the results to the command line.
    def search(query, case_sensitive: false, whole_sentence: false)
      Wgit.indexed_search(
        query, case_sensitive: case_sensitive, whole_sentence: whole_sentence
      )
    end

    private

    # DSL method used within the block passed to DatabaseHelper#seed.
    # Seeds a Url into the DB.
    def url(hashes_or_int = 1)
      if hashes_or_int&.is_a?(Enumerable)
        if hashes_or_int.is_a?(Hash)
          @@urls << hashes_or_int
        else
          @@urls.concat(hashes_or_int)
        end
      else
        hashes_or_int.times { @@urls << Wgit::DatabaseDevData.url }
      end
    end

    # DSL method used within the block passed to DatabaseHelper#seed.
    # Seeds a Document into the DB.
    def doc(hashes_or_int = 1)
      if hashes_or_int&.is_a?(Enumerable)
        if hashes_or_int.is_a?(Hash)
          @@docs << hashes_or_int
        else
          @@docs.concat(hashes_or_int)
        end
      else
        hashes_or_int.times { @@docs << Wgit::DatabaseDevData.doc }
      end
    end

    alias nuke  clear_db
    alias urls  url
    alias docs  doc
    alias index index_site
  end
end
