# frozen_string_literal: true

require_relative 'crawler'
require_relative 'database/database'

module Wgit
  # Class which crawls and saves the Documents to a database. Can be thought of
  # as a combination of Wgit::Crawler and Wgit::Database.
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
    def initialize(database = Wgit::Database::MongoDB.new, crawler = Wgit::Crawler.new)
      @db      = database
      @crawler = crawler
    end

    # Retrieves uncrawled url's from the database and recursively crawls each
    # site storing their internal pages into the database and adding their
    # external url's to be crawled later on. Logs info on the crawl using
    # Wgit.logger as it goes along. This method will honour all site's
    # robots.txt and 'noindex' requests.
    #
    # @param max_sites [Integer] The number of separate and whole
    #   websites to be crawled before the method exits. Defaults to -1 which
    #   means the crawl will occur until manually stopped (Ctrl+C), the
    #   max_data has been reached, or it runs out of external urls to index.
    # @param max_data [Integer] The maximum amount of bytes that will be
    #   scraped from the web (default is 1GB). Note, that this value is used to
    #   determine when to stop crawling; it's not a guarantee of the max data
    #   that will be obtained.
    # @param max_urls_per_iteration [Integer] The maximum number of uncrawled
    #   urls to index for each iteration, before checking max_sites and
    #   max_data, possibly ending the crawl.
    def index_www(max_sites: -1, max_data: 1_048_576_000, max_urls_per_iteration: 10)
      if max_sites.negative?
        Wgit.logger.info("Indexing until the database has been filled or it \
runs out of urls to crawl (which might be never)")
      end
      site_count = 0

      while keep_crawling?(site_count, max_sites, max_data)
        Wgit.logger.info("Current database size: #{@db.size}")

        uncrawled_urls = @db.uncrawled_urls(limit: max_urls_per_iteration)

        if uncrawled_urls.empty?
          Wgit.logger.info('No urls to crawl, exiting')

          return
        end
        Wgit.logger.info("Starting indexing loop for: #{uncrawled_urls.map(&:to_s)}")

        docs_count = 0
        urls_count = 0

        uncrawled_urls.each do |url|
          unless keep_crawling?(site_count, max_sites, max_data)
            Wgit.logger.info("Reached max number of sites to crawl or \
database capacity, exiting")

            return
          end
          site_count += 1

          parser = parse_robots_txt(url)
          if parser&.no_index?
            upsert_url_and_redirects(url)

            next
          end

          site_docs_count = 0
          ext_links = @crawler.crawl_site(
            url, allow_paths: parser&.allow_paths, disallow_paths: parser&.disallow_paths
          ) do |doc|
            next if doc.empty? || no_index?(@crawler.last_response, doc)

            upsert_doc(doc)
            docs_count += 1
            site_docs_count += 1
          end

          upsert_url_and_redirects(url)

          urls_count += upsert_external_urls(ext_links)
        end

        Wgit.logger.info("Crawled and indexed documents for #{docs_count} \
url(s) during this iteration")
        Wgit.logger.info("Found and saved #{urls_count} external url(s) for \
future iterations")
      end

      nil
    end

    # Crawls a single website's pages and stores them into the database.
    # There is no max download limit so be careful which sites you index.
    # Logs info on the crawl using Wgit.logger as it goes along. This method
    # will honour the site's robots.txt and 'noindex' requests.
    #
    # @param url [Wgit::Url] The base Url of the website to crawl.
    # @param insert_externals [Boolean] Whether or not to insert the website's
    #   external Url's into the database.
    # @param follow [String] The xpath extracting links to be followed during
    #   the crawl. This changes how a site is crawled. Only links pointing to
    #   the site domain are allowed. The `:default` is any `<a>` href returning
    #   HTML.
    # @param allow_paths [String, Array<String>] Filters the `follow:` links by
    #   selecting them if their path `File.fnmatch?` one of allow_paths.
    # @param disallow_paths [String, Array<String>] Filters the `follow` links
    #   by rejecting them if their path `File.fnmatch?` one of disallow_paths.
    # @yield [doc] Given the Wgit::Document of each crawled web page before
    #   it's inserted into the database allowing for prior manipulation. Return
    #   nil or false from the block to prevent the document from being saved
    #   into the database.
    # @return [Integer] The total number of webpages/documents indexed.
    def index_site(
      url, insert_externals: false, follow: :default,
      allow_paths: nil, disallow_paths: nil
    )
      parser = parse_robots_txt(url)
      if parser&.no_index?
        upsert_url_and_redirects(url)

        return 0
      end

      allow_paths, disallow_paths = merge_paths(parser, allow_paths, disallow_paths)
      crawl_opts = { follow:, allow_paths:, disallow_paths: }
      total_pages_indexed = 0

      ext_urls = @crawler.crawl_site(url, **crawl_opts) do |doc|
        next if no_index?(@crawler.last_response, doc)

        result = block_given? ? yield(doc) : true

        if result && !doc.empty?
          upsert_doc(doc)
          total_pages_indexed += 1
        end
      end

      upsert_url_and_redirects(url)
      upsert_external_urls(ext_urls) if insert_externals && ext_urls

      Wgit.logger.info("Crawled and indexed #{total_pages_indexed} documents \
for the site: #{url}")

      total_pages_indexed
    end

    # Crawls one or more webpages and stores them into the database.
    # There is no max download limit so be careful of large pages.
    # Logs info on the crawl using Wgit.logger as it goes along.
    # This method will honour the site's robots.txt and 'noindex' requests
    # in relation to the given urls.
    #
    # @param urls [*Wgit::Url] The webpage Url's to crawl.
    # @param insert_externals [Boolean] Whether or not to insert the webpages
    #   external Url's into the database.
    # @yield [doc] Given the Wgit::Document of the crawled webpage,
    #   before it's inserted into the database allowing for prior
    #   manipulation. Return nil or false from the block to prevent the
    #   document from being saved into the database.
    # @raise [StandardError] if no urls are provided.
    def index_urls(*urls, insert_externals: false, &block)
      raise 'You must provide at least one Url' if urls.empty?

      opts = { insert_externals: }
      Wgit::Utils.each(urls) { |url| index_url(url, **opts, &block) }

      nil
    end

    # Crawls a single webpage and stores it into the database.
    # There is no max download limit so be careful of large pages.
    # Logs info on the crawl using Wgit.logger as it goes along.
    # This method will honour the site's robots.txt and 'noindex' requests
    # in relation to the given url.
    #
    # @param url [Wgit::Url] The webpage Url to crawl.
    # @param insert_externals [Boolean] Whether or not to insert the webpages
    #   external Url's into the database.
    # @yield [doc] Given the Wgit::Document of the crawled webpage,
    #   before it's inserted into the database allowing for prior
    #   manipulation. Return nil or false from the block to prevent the
    #   document from being saved into the database.
    def index_url(url, insert_externals: false)
      parser = parse_robots_txt(url)
      if parser && (parser.no_index? || contains_path?(parser.disallow_paths, url))
        upsert_url_and_redirects(url)

        return
      end

      document = @crawler.crawl_url(url) do |doc|
        break if no_index?(@crawler.last_response, doc)

        result = block_given? ? yield(doc) : true
        upsert_doc(doc) if result && !doc.empty?
      end

      upsert_url_and_redirects(url)

      ext_urls = document&.external_links
      upsert_external_urls(ext_urls) if insert_externals && ext_urls

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
    # collection deliberately prevents duplicate inserts. If the document
    # already exists, then it will be updated in the DB.
    #
    # @param doc [Wgit::Document] The document to write to the DB.
    def upsert_doc(doc)
      if @db.upsert(doc)
        Wgit.logger.info("Saved document for url: #{doc.url}")
      else
        Wgit.logger.info("Updated document for url: #{doc.url}")
      end
    end

    # Upsert the url and its redirects, setting all to crawled = true.
    #
    # @param url [Wgit::Url] The url to write to the DB.
    # @return [Integer] The number of upserted urls (url + redirect urls).
    def upsert_url_and_redirects(url)
      url.crawled = true unless url.crawled?

      # Upsert the url and any url redirects, setting them as crawled also.
      @db.bulk_upsert(url.redirects_journey)
    end

    # Write the external urls to the DB. For any external url, its origin will
    # be inserted e.g. if the external url is http://example.com/contact then
    # http://example.com will be inserted into the database. Note that the
    # unique url index on the urls collection deliberately prevents duplicate
    # inserts.
    #
    # @param urls [Array<Wgit::Url>] The external urls to write to the DB.
    # @return [Integer] The number of upserted urls.
    def upsert_external_urls(urls)
      urls = urls
             .reject(&:invalid?)
             .map(&:to_origin)
             .uniq
      return 0 if urls.empty?

      count = @db.bulk_upsert(urls)
      Wgit.logger.info("Saved #{count} external urls")

      count
    end

    private

    # Crawls and parses robots.txt file (if found). Returns the parser or nil.
    def parse_robots_txt(url)
      robots_url = url.to_origin.join('/robots.txt')

      Wgit.logger.info("Crawling for robots.txt: #{robots_url}")

      doc = @crawler.crawl_url(robots_url)
      return nil if !@crawler.last_response.ok? || doc.empty?

      parser = Wgit::RobotsParser.new(doc.content)

      Wgit.logger.info("robots.txt allow paths: #{parser.allow_paths}")
      Wgit.logger.info("robots.txt disallow paths: #{parser.disallow_paths}")
      if parser.no_index?
        Wgit.logger.info('robots.txt has banned wgit indexing, skipping')
      end

      parser
    end

    # Takes the user defined allow/disallow_paths and merges robots paths
    # into them. The allow/disallow_paths vars each can be of type nil, String,
    # Enumerable<String>.
    def merge_paths(parser, allow_paths, disallow_paths)
      return allow_paths, disallow_paths unless parser&.rules?

      allow = allow_paths || []
      allow = [allow] unless allow.is_a?(Enumerable)

      disallow = disallow_paths || []
      disallow = [disallow] unless disallow.is_a?(Enumerable)

      allow.concat(parser.allow_paths)
      disallow.concat(parser.disallow_paths)

      [allow, disallow]
    end

    # Returns true if url is included in the given paths.
    def contains_path?(paths, url)
      paths.any? { |path| Wgit::Url.new(path).to_path == url.to_path }
    end

    # Returns if the last_response or doc #no_index? is true or not.
    def no_index?(last_response, doc)
      url = last_response.url.to_s
      if last_response.no_index?
        Wgit.logger.info("Skipping page due to no-index response header: #{url}")
        return true
      end

      if doc&.no_index?
        Wgit.logger.info("Skipping page due to no-index HTML meta tag: #{url}")
        return true
      end

      false
    end

    alias_method :database, :db
    alias_method :index,    :index_urls
    alias_method :index_r,  :index_site
  end
end
