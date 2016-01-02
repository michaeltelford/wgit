require_relative 'utils'
require 'uri'

# @author Michael Telford
# Class modeling a web based URL.
# Can be an internal link e.g. "about.html" 
# or a full URL e.g. "http://www.google.co.uk".
class Url < String
    attr_accessor :crawled, :date_crawled
    
    def initialize(url_or_doc, crawled = false, date_crawled = nil)
        if (url_or_doc.is_a?(String))
            url = url_or_doc
        else
            # Init from a mongo collection document.
            url = url_or_doc[:url]
            crawled = url_or_doc[:crawled].nil? ? false : url_or_doc[:crawled]
            date_crawled = url_or_doc[:date_crawled]
        end
        @uri = URI(url)
        @crawled = crawled
        @date_crawled = date_crawled
        super(url)
    end
    
    def self.validate(url)
        if Url.relative_link?(url)
            raise "Invalid url (relative link): #{url}"
        end
        unless url.start_with?("http://") or url.start_with?("https://")
            raise "Invalid url (missing protocol prefix): #{url}"
        end
        if URI.regexp.match(url).nil?
            raise "Invalid url: #{url}"
        end
    end
    
    def self.valid?(url)
        Url.validate(url)
        true
    rescue
        false
    end
    
    def self.prefix_protocol!(url, https = false)
        if Url.relative_link?(url)
            raise "Invalid url (relative link): #{url}"
        end
        unless url.start_with?("http://") or url.start_with?("https://")
            if https
                url.replace("https://#{url}")
            else
                url.replace("http://#{url}")
            end
        end
    end
    
    # URI.split("http://www.google.co.uk/about.html") returns the following:
    # array[2]: "www.google.co.uk", array[5]: "/about.html"
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
        Url.new(url + "/" + link)
    end
    
    def relative_link?
        Url.relative_link?(self)
    end
    
    def concat(link)
        Url.concat(self, link)
    end
    
    def crawled=(bool)
        @crawled = bool
        @date_crawled = bool ? Utils.time_stamp : nil
    end
    
    def to_uri
        @uri
    end
    
    def to_host
        Url.new(@uri.host)
    end
    
    def to_base
        if Url.relative_link?(self)
            raise "A relative link doesn't have a base URL: #{self}"
        end
        url_segs = URI.split(self)
        if url_segs[0].nil? or url_segs[2].nil? or url_segs[2].empty?
            raise "Both a protocol and host are needed: #{self}"
        end
        base = "#{url_segs[0]}://#{url_segs[2]}"
        Url.new(base)
    end
    
    def to_h
        ignore = [:@uri]
        h = Utils.to_h(self, ignore)
        Hash[h.to_a.insert(0, ["url", self])] # Insert url at position 0.
    end
    
    alias :to_hash :to_h
    alias :host :to_host
    alias :base :to_base
    alias :internal_link? :relative_link?
end
