module Wgit
  # Class to inherit from, as an alternative form of using the `Wgit::DSL`.
  # All subclasses must define a `#parse(doc, &block)` method.
  class Base
    extend Wgit::DSL

    # Runs once before the crawl/index is run. Override as needed.
    def setup; end

    # Runs once after the crawl/index is complete. Override as needed.
    def teardown; end

    # Runs the crawl/index passing each crawled `Wgit::Document` and the given
    # block to the subclass's `#parse` method.
    def self.run(&block)
      crawl_method = @method || :crawl
      obj = new

      unless obj.respond_to?(:parse)
        raise "#{obj.class} must respond_to? #parse(doc, &block)"
      end

      obj.setup
      send(crawl_method) { |doc| obj.parse(doc, &block) }
      obj.teardown

      obj
    end

    # Sets the crawl/index method to call when `Base.run` is called.
    # The mode method must match one defined in the `Wgit::Crawler` or
    # `Wgit::Indexer` class.
    #
    # @param method [Symbol] The crawl/index method to call.
    def self.mode(method)
      @method = method
    end
  end
end
