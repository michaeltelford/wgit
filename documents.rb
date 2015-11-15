# @author Michael Telford
# Class modeling a collection of HTML web documents.
class Documents < Hash
	def initialize(default = nil)
		super
	end
    
    def []=(url, value)
        url.strip!
        raise "Url already exists" if self.has_key?(url)
        raise "value must be a Document object" unless value.is_a?(Document)
        super
    end
    
    def filter!(urls)
        urls.reject! { |url| keys.include?(url) }
    end
    
    def search(text)
        results = {}
        values.each do |doc|
            results[doc.url] = doc.search(text)
        end
        results
    end
end
