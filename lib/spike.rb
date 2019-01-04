require_relative 'wgit'
require_relative 'wgit/core_ext' # => Provides the String#to_url and Enumerable#to_urls methods.

my_pages_keywords = ["altitude", "mountaineering", "adventure"]
my_pages_missing_keywords = []

competitor_urls = [
	"http://altitudejunkies.com", 
	"http://www.mountainmadness.com", 
	"http://www.adventureconsultants.com"
].to_urls

crawler = Wgit::Crawler.new *competitor_urls

crawler.crawl do |doc|
  if doc.keywords.respond_to? :-
    puts "The keywords for #{doc.url} are: \n#{doc.keywords}\n\n"
    my_pages_missing_keywords.concat(doc.keywords - my_pages_keywords)
  end
end

puts "Your pages compared to your competitors are missing the following keywords:"
puts my_pages_missing_keywords.uniq!
