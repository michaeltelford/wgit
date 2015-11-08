# @author Michael Telford
# Class modeling a collection of HTML web documents.
class Documents < Hash
	def initialize(default = nil)
		super
	end
    
    def []=(url, value)
        # Don't yet know how we want to handle duplicate urls
        # and is below the best way?
        #raise "Url already exists" if self.has_key?(url)
        unless value.is_a?(Document) or value.nil?
            raise "value must be a Document object"
        end
        super
    end
    
    def filter!(urls)
        urls.reject! { |url| keys.include?(url) }
    end
    
    def search_text(text)
        results = []
        values.each { |doc| results.concat(doc.search_text(text)) }
        results
    end
end
