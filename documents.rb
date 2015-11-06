# @author Michael Telford
# Class modeling a collection of HTML web documents.
class Documents < Hash
	def initialize(default = nil)
		super
	end
    
    # Don't yet know how we want to handle duplicate urls
    # and is below the best way?
    #def []=(url, value)
    #    raise "Url already exists" if self.has_key?(url)
    #    super
    #end
    
    def filter!(urls)
        #urls = urls - self.keys
        urls.reject! { |url| keys.include?(url) }
    end
end
