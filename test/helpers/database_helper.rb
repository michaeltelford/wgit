# frozen_string_literal: true

require_relative 'database_test_data'
require 'mongo'

# Helper class used to manipulate the database.
module DatabaseHelper
  # A connection to the database is established when this module is included.
  def self.included(_base)
    @@db ||= Wgit::Database.new

    @@urls = []
    @@docs = []
  end

  # Returns the connected Wgit::Database instance.
  def database
    @@db
  end

  # Deletes everything in the urls and documents collections.
  def clear_db
    @@db.clear_db
  end

  # Seed what's in the block, comprising of url and doc method calls
  # (from this module). An integer can be used to specify how many default
  # objects should be seeded, defaults to 1; or provide your own Wgit:Url and
  # Wgit:Document instances (which are passed through Wgit::Model). Hashes
  # are also supported and will be merged with Model.common_insert_data.
  #
  # Returns the number of seeded/inserted documents in the DB.
  #
  # Code example:
  #   seed do
  #     url(Wgit::Url | Hash)
  #     doc(Wgit::Document | Hash)
  #     urls 3  # Seeds 3 of the default dev url records.
  #     doc     # Seeds 1 of the default dev doc records.
  #   end
  def seed(&block)
    raise 'Must provide a block' unless block_given?

    @@urls.clear
    @@docs.clear

    # &block populates the @@urls and @@docs arrays.
    instance_eval(&block)

    begin
      @@db.client[:urls].insert_many(@@urls) unless @@urls.empty?
      @@db.client[:documents].insert_many(@@docs) unless @@docs.empty?

      @@urls.count + @@docs.count
    rescue StandardError => e
      err_msg = e.respond_to?(:result) ? e.result['writeErrors'] : e.message
      raise "Write to DB failed - remember that both urls and docs won't \
accept duplicate urls. Exception details: #{err_msg}"
    end
  end

  # Returns if the url_hash/record exists in the DB.
  #
  # Different from Wgit::Database#url? because it asserts the full url_hash,
  # not just the presence of the unique 'url' field.
  def url?(url_hash)
    @@db.client[:urls].find(url_hash).any?
  end

  # Returns if the doc_hash/record exists in the DB.
  #
  # Different from Wgit::Database#doc? because it asserts the full doc_hash,
  # not just the presence of the unique 'url' field.
  def doc?(doc_hash)
    @@db.client[:documents].find(doc_hash).any?
  end

  private

  # DSL method used within the block passed to DatabaseHelper#seed.
  # Seeds one or more Wgit::Urls into the DB.
  def url(url_or_int = 1)
    case url_or_int
    when String
      parsed_url = Wgit::Url.parse(url_or_int)
      append_url(parsed_url)
    when Array
      url_or_int.each { |url| append_url(url) }
    when Integer
      url_or_int.times { @@urls << DatabaseTestData.url }
    else
      raise "Invalid data type: #{url_or_int.class}"
    end
  end

  # DSL method used within the block passed to DatabaseHelper#seed.
  # Seeds one or more Wgit::Documents into the DB.
  def doc(doc_or_int = 1)
    case doc_or_int
    when Wgit::Document
      append_doc(doc_or_int)
    when Array
      doc_or_int.each { |doc| append_doc(doc) }
    when Integer
      doc_or_int.times { @@docs << DatabaseTestData.doc }
    else
      raise "Invalid data type: #{url_or_int.class}"
    end
  end

  # Appends a Url to @@urls.
  def append_url(url)
    model_hash = case url
                  when Wgit::Url
                    Wgit::Model.url(url)
                  when Hash
                    url
                  else
                    raise "Invalid data type: #{url.class}"
                  end

    @@urls << model_hash.merge(Wgit::Model.common_insert_data)
  end

  # Appends a Document to @@docs.
  def append_doc(doc)
    model_hash = case doc
                  when Wgit::Document
                    Wgit::Model.document(doc)
                  when Hash
                    doc
                  else
                    raise "Invalid data type: #{doc.class}"
                  end

    @@docs << model_hash.merge(Wgit::Model.common_insert_data)
  end

  alias urls url
  alias docs doc
end
