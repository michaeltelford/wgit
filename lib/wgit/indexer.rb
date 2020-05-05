# frozen_string_literal: true

require_relative 'crawler'
require_relative 'database/database'

module Wgit
  # Class which crawls and saves the indexed Documents to a database. Can be
  # thought of as a combination of Wgit::Crawler and Wgit::Database.
  class Indexer
    # The crawler used to index the WWW.
    attr_reader :crawler

    # The database instance used to store Urls and Documents in.
    attr_reader :db

    # Initialize the Indexer.
    #
    # @param database [Wgit::Database] The database instance (already
    #   initialized and connected) used to index.
    # @param crawler [Wgit::Crawler] The crawler instance used to index.
    def initialize(database, crawler = Wgit::Crawler.new)
      @db      = database
      @crawler = crawler
    end

    # Retrieves uncrawled url's from the database and recursively crawls each
    # site storing their internal pages into the database and adding their
    # external url's to be crawled later on. Logs info on the crawl using
    # Wgit.logger as it goes along.
    #
    # @param max_sites [Integer] The number of separate and whole
    #   websites to be crawled before the method exits. Defaults to -1 which
    #   means the crawl will occur until manually stopped (Ctrl+C etc).
    # @param max_data [Integer] The maximum amount of bytes that will be
    #   scraped from the web (default is 1GB). Note, that this value is used to
    #   determine when to stop crawling; it's not a guarantee of the max data
    #   that will be obtained.
    def index_www(max_sites: -1, max_data: 1_048_576_000)
      if max_sites.negative?
        Wgit.logger.info("Indexing until the database has been filled or it \
runs out of urls to crawl (which might be never).")
      end
      site_count = 0

      while keep_crawling?(site_count, max_sites, max_data)
        Wgit.logger.info("Current database size: #{@db.size}")

        uncrawled_urls = @db.uncrawled_urls(limit: 100)

        if uncrawled_urls.empty?
          Wgit.logger.info('No urls to crawl, exiting.')

          return
        end
        Wgit.logger.info("Starting crawl loop for: #{uncrawled_urls}")

        docs_count = 0
        urls_count = 0

        uncrawled_urls.each do |url|
          unless keep_crawling?(site_count, max_sites, max_data)
            Wgit.logger.info("Reached max number of sites to crawl or \
database capacity, exiting.")

            return
          end
          site_count += 1

          site_docs_count = 0
          ext_links = @crawler.crawl_site(url) do |doc|
            if !doc.empty? && write_doc_to_db(doc)
              docs_count += 1
              site_docs_count += 1
            end
          end

          raise 'Error updating url' unless @db.update(url) == 1

          urls_count += write_urls_to_db(ext_links)

          Wgit.logger.info("Crawled and saved #{site_docs_count} docs for the \
site: #{url}")
        end

        Wgit.logger.info("Crawled and saved docs for #{docs_count} url(s) \
overall for this iteration.")
        Wgit.logger.info("Found and saved #{urls_count} external url(s) for \
the next iteration.")

        nil
      end
    end

    # Crawls a single website's pages and stores them into the database.
    # There is no max download limit so be careful which sites you index.
    # Logs info on the crawl using Wgit.logger as it goes along.
    #
    # @param url [Wgit::Url] The base Url of the website to crawl.
    # @param insert_externals [Boolean] Whether or not to insert the website's
    #   external Url's into the database.
    # @param allow_paths [String, Array<String>] Filters links by selecting
    #   them if their path `File.fnmatch?` one of allow_paths.
    # @param disallow_paths [String, Array<String>] Filters links by rejecting
    #   them if their path `File.fnmatch?` one of disallow_paths.
    # @yield [doc] Given the Wgit::Document of each crawled web page before
    #   it's inserted into the database allowing for prior manipulation. Return
    #   nil or false from the block to prevent the document from being saved
    #   into the database.
    # @return [Integer] The total number of webpages/documents indexed.
    def index_site(
      url, insert_externals: true, allow_paths: nil, disallow_paths: nil
    )
      crawl_opts = { allow_paths: allow_paths, disallow_paths: disallow_paths }
      total_pages_indexed = 0

      ext_urls = @crawler.crawl_site(url, crawl_opts) do |doc|
        result = block_given? ? yield(doc) : true

        if result && !doc.empty? && write_doc_to_db(doc)
          total_pages_indexed += 1
          Wgit.logger.info("Crawled and saved internal page: #{doc.url}")
        end
      end

      @db.url?(url) ? @db.update(url) : @db.insert(url)

      if insert_externals && ext_urls
        num_inserted_urls = write_urls_to_db(ext_urls)
        Wgit.logger.info("Found and saved #{num_inserted_urls} external url(s)")
      end

      Wgit.logger.info("Crawled and saved #{total_pages_indexed} docs for the \
site: #{url}")

      total_pages_indexed
    end

    # Crawls one or more webpages and stores them into the database.
    # There is no max download limit so be careful of large pages.
    # Logs info on the crawl using Wgit.logger as it goes along.
    #
    # @param urls [*Wgit::Url] The webpage Url's to crawl.
    # @param insert_externals [Boolean] Whether or not to insert the webpages
    #   external Url's into the database.
    # @yield [doc] Given the Wgit::Document of the crawled webpage,
    #   before it's inserted into the database allowing for prior
    #   manipulation. Return nil or false from the block to prevent the
    #   document from being saved into the database.
    def index_urls(*urls, insert_externals: true, &block)
      raise 'You must provide at least one Url' if urls.empty?

      opts = { insert_externals: insert_externals }
      Wgit::Utils.each(urls) { |url| index_url(url, opts, &block) }

      nil
    end

    # Crawls a single webpage and stores it into the database.
    # There is no max download limit so be careful of large pages.
    # Logs info on the crawl using Wgit.logger as it goes along.
    #
    # @param url [Wgit::Url] The webpage Url to crawl.
    # @param insert_externals [Boolean] Whether or not to insert the webpages
    #   external Url's into the database.
    # @yield [doc] Given the Wgit::Document of the crawled webpage,
    #   before it's inserted into the database allowing for prior
    #   manipulation. Return nil or false from the block to prevent the
    #   document from being saved into the database.
    def index_url(url, insert_externals: true)
      document = @crawler.crawl_url(url) do |doc|
        result = block_given? ? yield(doc) : true

        if result && !doc.empty? && write_doc_to_db(doc)
          Wgit.logger.info("Crawled and saved internal page: #{doc.url}")
        end
      end

      @db.url?(url) ? @db.update(url) : @db.insert(url)

      ext_urls = document&.external_links
      if insert_externals && ext_urls
        num_inserted_urls = write_urls_to_db(ext_urls)
        Wgit.logger.info("Found and saved #{num_inserted_urls} external url(s)")
      end

      nil
    end

    protected

    # Returns whether or not to keep crawling based on the DB size and current
    # loop iteration.
    #
    # @param site_count [Integer] The current number of crawled sites.
    # @param max_sites [Integer] The maximum number of sites to crawl
    #   before stopping. Use -1 for an infinite number of sites.
    # @param max_data [Integer] The maximum amount of data to crawl before
    #   stopping.
    # @return [Boolean] True if the crawl should continue, false otherwise.
    def keep_crawling?(site_count, max_sites, max_data)
      return false if @db.size >= max_data
      return true  if max_sites.negative?

      site_count < max_sites
    end

    # Write the doc to the DB. Note that the unique url index on the documents
    # collection deliberately prevents duplicate inserts.
    #
    # @param doc [Wgit::Document] The document to write to the DB.
    # @return [Boolean] True if the write was successful, false otherwise.
    def write_doc_to_db(doc)
      @db.insert(doc)
      Wgit.logger.info("Saved document for url: #{doc.url}")

      true
    rescue Mongo::Error::OperationFailure
      Wgit.logger.info("Document already exists: #{doc.url}")

      false
    end

    # Write the urls to the DB. Note that the unique url index on the urls
    # collection deliberately prevents duplicate inserts.
    #
    # @param urls [Array<Wgit::Url>] The urls to write to the DB.
    # @return [Boolean] True if the write was successful, false otherwise.
    def write_urls_to_db(urls)
      count = 0

      return count unless urls.respond_to?(:each)

      urls.each do |url|
        if url.invalid?
          Wgit.logger.info("Ignoring invalid external url: #{url}")
          next
        end

        @db.insert(url)
        count += 1
        Wgit.logger.info("Inserted external url: #{url}")
      rescue Mongo::Error::OperationFailure
        Wgit.logger.info("External url already exists: #{url}")
      end

      count
    end

    alias index       index_urls
    alias index_pages index_urls
    alias index_page  index_url
    alias index_r     index_site
  end
end
