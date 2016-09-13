# Wgit

Wgit is wget on steroids with an easy to use API.

Wgit is a WWW indexer/scraper which crawls URL's and retrieves their page contents for later use. Also included in this package is a means to search indexed documents stored in a database. Therefore this library provides the main components of a WWW search engine. You can also use Wgit to copy entire website's HTML making it far more powerful than wget. The Wgit API is easily extendable allowing you to easily pull out the parts of a webpage that are important to you, the CSS or JS links for example. 

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'wgit'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install wgit

## Basic Usage

Below shows an example of API usage in action and gives an idea of how you can use Wgit in your own code.

```ruby
require 'wgit'

crawler = Wgit::Crawler.new
url = Wgit::Url.new "https://wikileaks.org/What-is-Wikileaks.html"

doc = crawler.crawl url
doc.stats # => {:url=>44, :html=>28133, :title=>17, :keywords=>0, :links=>35, :text_length=>67, :text_bytes=>13735}

doc.class # => Wgit::Document
Wgit::Document.instance_methods(false).sort # => [:author, :empty?, :external_links, :external_urls, :html, :internal_full_links, :internal_links, :keywords, :links, :relative_full_links, :relative_full_urls, :relative_links, :relative_urls, :score, :search, :search!, :size, :stats, :text, :title, :to_h, :to_hash, :url, :xpath]

results = doc.search "corruption"
results.first # => "ial materials involving war, spying and corruption. It has so far published more"
```

## Practical Examples

Below are some practical examples of Wgit in use. You can copy and run the code for yourself. 
Make sure to replace the CONNECTION_DETAILS with your own when using the Database example. 

### WWW HTML Indexer

See the Wgit::WebCrawler documentation and source code for an already built example of a WWW HTML 
indexer. It will crawl any external url's (in the database) and index their markup 
for later use, be it searching or otherwise. 

### CSS Indexer

The below script downloads the contents of Facebook's (index page's) first css link. 

```ruby
require 'wgit'
require 'wgit/core_ext' # => Provides the String#to_url and Array#to_urls methods.

crawler = Wgit::Crawler.new
url = "https://www.facebook.com".to_url

doc = crawler.crawl url

# Provide your own xpath to search the HTML using Nokogiri.
css_urls = doc.xpath "//link[@rel='stylesheet']/@href"

css_urls.class # => Nokogiri::XML::NodeSet
css_url = css_urls.first.value # => "https://static.xx.fbcdn.net/rsrc.php/v3/yE/r/uqWZrDdEiFq.css"

css = crawler.crawl css_url.to_url
css[0..50] # => ".UIContentTopper{padding:14px 0 0 17px;margin:50px "
```

### Keyword Indexer (SEO Helper)

The below script downloads the contents of several webpages, pulls out their keywords for comparison.
Such a script might be used by marketers for SEO optimisation for example. 

```ruby
require 'wgit'
require 'wgit/core_ext' # => Provides the String#to_url and Array#to_urls methods.

my_pages_keywords = ["altitude", "mountaineering", "adventure"]
my_pages_missing_keywords = []

competitor_urls = [
	"http://altitudejunkies.com", 
	"http://www.mountainmadness.com", 
	"http://www.adventureconsultants.com"
].to_urls

crawler = Wgit::Crawler.new competitor_urls

crawler.crawl do |doc|
	puts "The keywords for #{doc.url} are: \n#{doc.keywords}\n\n"
	my_pages_missing_keywords.concat(doc.keywords - my_pages_keywords)
end

puts "Your pages compared to your competitors are missing the following keywords:"
puts my_pages_missing_keywords.uniq!
```
### Database Example

The below script shows how to use Wgit's database functionality (using MongoDB) to crawl and 
search HTML documents. 

Currently the only supported DBMS is MongoDB. See [mLab](https://mlab.com) for a free (small) 
account or provide your own database instance. 

```ruby
require 'wgit'
require 'wgit/core_ext' # => Provides the String#to_url and Array#to_urls methods.

# Here we create our own document rather than crawl one. 
doc = Wgit::Document.new(
	"http://test-url.com".to_url, 
	"<p>Some text to search for.</p><a href='http://www.google.co.uk'>Click me!</a>"
)

# Set your DB connection details.
Wgit::CONNECTION_DETAILS = {
  :host           => "<host_machine>",
  :port           => "27017", # MongoDB's default port is shown here.
  :db             => "<database_name>",
  :uname          => "<username>",
  :pword          => "<password>"
}.freeze

db = Wgit::Database.new
db.insert doc

# Searching the DB returns documents with 'hits'. 
results = db.search "text"

doc == results.first # => true

# Searching a document returns text snippets with 'hits' within that document. 
doc.search("text").first # => "Some text to search for."

db.insert doc.external_links

urls_to_crawl = db.uncrawled_urls # => Results will include doc.external_links. 
```

## Extending the API

TODO. 

Notes:

- Any links should be mapped into Wgit::Url's, Url's are treated as Strings 
when being inserted into the DB. 
- Any object like a Nokogiri object will not be inserted into the DB, its up 
to you to map each object to a native type e.g. String, Boolean etc. 

## Notes

Below are some notes to keep in mind when using Wgit:

- All Url's should be prefixed with the appropiate protocol e.g. http://
- Url redirects will not be followed and nil will be returned from the crawl. 
- Currently the only supported DBMS is MongoDB. 

## Executable

Currently there is no executable provided with Wgit, however...

In future versions of Wgit a `wgit` executable will be provided as part of the gem. This executable will provide the capability to crawl a Url from the command line just like wget but you'll be able to do much more like recursively crawl entire sites and easily store the resulting markup in a Database or to a file. 

## Development

After checking out the repo, run `./bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `./bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake RELEASE[remote]` (remote being the correct Git remote e.g. origin), which will create a git tag for the version, push any git commits and tags, and push the `*.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on [GitHub](https://github.com/michaeltelford/wgit).

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
