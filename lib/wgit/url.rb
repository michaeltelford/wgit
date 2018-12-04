require_relative 'utils'
require 'uri'

module Wgit
  
  # @author Michael Telford
  # Class modeling a web based URL.
  # Can be an internal link e.g. "about.html" or a full URL 
  # e.g. "http://www.google.co.uk".
  class Url < String
      attr_accessor :crawled, :date_crawled
    
      def initialize(url_or_obj, crawled = false, date_crawled = nil)
        # Init from a URL String.
        if url_or_obj.is_a?(String)
            url = url_or_obj
        # Else init from a database object/document.
        else
            obj = url_or_obj
            url = obj.fetch("url") # Should always be present.
            crawled = obj.fetch("crawled", false)
            date_crawled = obj["date_crawled"]
        end
        
        @uri = URI(url)
        @crawled = crawled
        @date_crawled = date_crawled
        
        super(url)
      end
    
      def self.validate(url)
          if Wgit::Url.relative_link?(url)
              raise "Invalid url (or a relative link): #{url}"
          end
          unless url.start_with?("http://") or url.start_with?("https://")
              raise "Invalid url (missing protocol prefix): #{url}"
          end
          if URI.regexp.match(url).nil?
              raise "Invalid url: #{url}"
          end
      end
    
      def self.valid?(url)
          Wgit::Url.validate(url)
          true
      rescue
          false
      end
    
      # Modifies the receiver url by prefixing it with a protocol.
      # Returns the url whether its been modified or not.
      def self.prefix_protocol(url, https = false)
          unless url.start_with?("http://") or url.start_with?("https://")
              if https
                  url.replace("https://#{url}")
              else
                  url.replace("http://#{url}")
              end
          end
          url
      end
    
      # URI.split("http://www.google.co.uk/about.html") returns the following:
      # array[2]: "www.google.co.uk", array[5]: "/about.html".
      # This means that all external links in a page are expected to have a 
      # protocol prefix e.g. "http://", otherwise the link is treated as an 
      # internal link (regardless of whether it is valid or not).
      def self.relative_link?(link)
          link_segs = URI.split(link)
          if not link_segs[2].nil? and not link_segs[2].empty?
              false
          elsif not link_segs[5].nil? and not link_segs[5].empty?
              true
          else
              raise "Invalid link: #{link}"
          end
      end
    
      def self.concat(host, link)
          url = host
          url.chop! if url.end_with?("/")
          link = link[1..-1] if link.start_with?("/")
          Wgit::Url.new(url + "/" + link)
      end
    
      def relative_link?
          Wgit::Url.relative_link?(self)
      end
    
      def valid?
          Wgit::Url.valid?(self)
      end
    
      def concat(link)
          Wgit::Url.concat(self, link)
      end
    
      def crawled=(bool)
          @crawled = bool
          @date_crawled = bool ? Wgit::Utils.time_stamp : nil
      end
    
      def to_uri
          @uri
      end
      
      def to_url
        self
      end
    
      # Given http://www.google.co.uk/about.html, www.google.co.uk is returned.
      def to_host
          Wgit::Url.new(@uri.host)
      end
    
      # URI.split("http://www.google.co.uk/about.html") returns the following:
      # array[0]: "http://", array[2]: "www.google.co.uk".
      # Returns array[0] + array[2] e.g. http://www.google.co.uk.
      def to_base
          if Wgit::Url.relative_link?(self)
              raise "A relative link doesn't have a base URL: #{self}"
          end
          url_segs = URI.split(self)
          if url_segs[0].nil? or url_segs[2].nil? or url_segs[2].empty?
              raise "Both a protocol and host are needed: #{self}"
          end
          base = "#{url_segs[0]}://#{url_segs[2]}"
          Wgit::Url.new(base)
      end
    
      def to_h
          ignore = ["@uri"]
          h = Wgit::Utils.to_h(self, ignore)
          Hash[h.to_a.insert(0, ["url", self])] # Insert url at position 0.
      end
    
      alias :to_hash :to_h
      alias :host :to_host
      alias :base :to_base
      alias :internal_link? :relative_link?
      alias :crawled? :crawled
  end
end
