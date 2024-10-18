# frozen_string_literal: true

require_relative "database_test_data"

# Helper module used to manipulate any database adapter. This module should
# be included in other DB helper modules. To do so, you must implement the
# following underlying methods:
#
# db                    # Returns a connected database adapter instance
# empty_db              # Empties the url and document collections
# seed_urls(url_hashes) # Seeds the given url hashes
# seed_docs(doc_hashes) # Seeds the given document hashes
# url?(url_hash)        # Returns true if the given url hash exists
# doc?(url_hash)        # Returns true if the given document hash exists
#
# The above method implementations should be done using the raw client for
# your DB adapter, not the Wgit adapter class that you're testing; this way
# the helpers won't fail before your DB tests fail.
module DatabaseHelper
  def self.included(_base)
    @@urls = []
    @@docs = []
  end

  # Seed what's in the block, comprising of url and doc method calls
  # (from this module). An integer can be used to specify how many default
  # objects should be seeded, defaults to 1; or provide your own Wgit:Url and
  # Wgit:Document instances (which are passed through Wgit::Model). Hashes are
  # also supported and will be merged with Wgit::Model.common_insert_data.
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
    raise "Must provide a block" unless block_given?

    @@urls.clear
    @@docs.clear

    # &block populates the @@urls and @@docs arrays.
    instance_eval(&block)

    seed_urls(@@urls) unless @@urls.empty?
    seed_docs(@@docs) unless @@docs.empty?

    @@urls.count + @@docs.count
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

  alias_method :urls, :url
  alias_method :docs, :doc
end
