module Wgit
  # Class to inherit from, as an alternative form of using the Wgit::DSL.
  class Base
    extend Wgit::DSL

    def self.run(&block)
      obj = new
      unless obj.respond_to?(:parse)
        raise "#{obj.class} must respond_to? #parse(doc, &block)"
      end

      crawl_method = @method || :crawl
      send(crawl_method) { |doc| obj.parse(doc, &block) }

      obj
    end

    def self.mode(method)
      @method = method
    end
  end
end
