# Wgit

Wgit is a Ruby gem similar in nature to GNU's `wget` tool. It provides an easy to use API for programmatic web scraping, indexing and searching.

Fundamentally, Wgit is a WWW indexer/scraper which crawls URL's, retrieves and serialises their page contents for later use. You can use Wgit to copy entire websites if required. Wgit also provides a means to search indexed documents stored in a database. Therefore, this library provides the main components of a WWW search engine. The Wgit API is easily extended allowing you to pull out the parts of a webpage that are important to you, the code snippets or tables for example. As Wgit is a library, it has uses in many different application types.

Check out this [example application](https://search-engine-rb.herokuapp.com) - a search engine (see its [repository](https://github.com/michaeltelford/search_engine)) built using Wgit and Sinatra, deployed to Heroku. Heroku's free tier is used so the initial page load may be slow. Try searching for "Ruby" or something else that's Ruby related.

## Table Of Contents

1. [Installation](#Installation)
2. [Basic Usage](#Basic-Usage)
3. [Documentation](#Documentation)
4. [Practical Examples](#Practical-Examples)
5. [Practical Database Example](#Practical-Database-Example)
6. [Extending The API](#Extending-The-API)
7. [Caveats](#Caveats)
8. [Executable](#Executable)
9. [Development](#Development)
10. [Contributing](#Contributing)
11. [License](#License)

## Installation

Add this line to your application's `Gemfile`:

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

doc.class # => Wgit::Document
doc.stats # => {
# :url=>44, :html=>28133, :title=>17, :keywords=>0,
# :links=>35, :text_length=>67, :text_bytes=>13735
#}

# doc responds to the following methods:
Wgit::Document.instance_methods(false).sort # => [
# :==, :[], :author, :css, :date_crawled, :doc, :empty?, :external_links,
# :external_urls, :html, :internal_full_links, :internal_links, :keywords,
# :links, :relative_full_links, :relative_full_urls, :relative_links,
# :relative_urls, :score, :search, :search!, :size, :stats, :text, :title,
# :to_h, :to_hash, :to_json, :url, :xpath
#]

results = doc.search "corruption"
results.first # => "ial materials involving war, spying and corruption.
              #     It has so far published more"
```

## Documentation

To see what's possible with the Wgit gem see the [docs](https://www.rubydoc.info/gems/wgit) or the [Practical Examples](#Practical-Examples) section below.

## Practical Examples

Below are some practical examples of Wgit in use. You can copy and run the code for yourself.

### WWW HTML Indexer

See the `Wgit::Indexer#index_the_web` documentation and source code for an already built example of a WWW HTML indexer. It will crawl any external url's (in the database) and index their markup for later use, be it searching or otherwise. It will literally crawl the WWW forever if you let it!

See the [Practical Database Example](#Practical-Database-Example) for information on how to setup a database for use with Wgit.

### Website Downloader

Wgit uses itself to download and save fixture webpages to disk (used in tests). See the script [here](https://github.com/michaeltelford/wgit/blob/master/test/mock/save_site.rb) and edit it for your own purposes.

### CSS Indexer

The below script downloads the contents of the first css link found on Facebook's index page.

```ruby
require 'wgit'
require 'wgit/core_ext' # Provides the String#to_url and Enumerable#to_urls methods.

crawler = Wgit::Crawler.new
url = "https://www.facebook.com".to_url

doc = crawler.crawl url

# Provide your own xpath (or css selector) to search the HTML using Nokogiri underneath.
hrefs = doc.xpath "//link[@rel='stylesheet']/@href"

hrefs.class # => Nokogiri::XML::NodeSet
href = hrefs.first.value # => "https://static.xx.fbcdn.net/rsrc.php/v3/y1/l/0,cross/NvZ4mNTW3Fd.css"

css = crawler.crawl href.to_url
css[0..50] # => "._3_s0._3_s0{border:0;display:flex;height:44px;min-"
```

### Keyword Indexer (SEO Helper)

The below script downloads the contents of several webpages and pulls out their keywords for comparison. Such a script might be used by marketeers for search engine optimisation for example.

```ruby
require 'wgit'

my_pages_keywords = ["Everest", "mountaineering school", "adventure"]
my_pages_missing_keywords = []

competitor_urls = [
  "http://altitudejunkies.com",
  "http://www.mountainmadness.com",
  "http://www.adventureconsultants.com"
]

crawler = Wgit::Crawler.new competitor_urls

crawler.crawl do |doc|
  # If there are keywords present in the web document.
  if doc.keywords.respond_to? :-
    puts "The keywords for #{doc.url} are: \n#{doc.keywords}\n\n"
    my_pages_missing_keywords.concat(doc.keywords - my_pages_keywords)
  end
end

if my_pages_missing_keywords.empty?
  puts "Your pages are missing no keywords, nice one!"
else
  puts "Your pages compared to your competitors are missing the following keywords:"
  puts my_pages_missing_keywords.uniq
end
```

## Practical Database Example

This next example requires a configured database instance.

Currently the only supported DBMS is MongoDB. See [mLab](https://mlab.com) for a free (small) account or provide your own MongoDB instance.

The currently supported versions of `mongo` are:

| Gem      | Database Engine |
| -------- | --------------- |
| ~> 2.8.0 | 3.6.12 (MMAPv1) |

### Setting Up MongoDB

Follow the steps below to configure MongoDB for use with Wgit. This is only needed if you want to read/write database records. The use of a database is entirely optional when using Wgit.

1) Create collections for: `documents` and `urls`.
2) Add a unique index for the `url` field in **both** collections.
3) Enable `textSearchEnabled` in MongoDB's configuration.
4) Create a *text search index* for the `documents` collection using:
```json
{
	"text": "text",
	"author": "text",
	"keywords": "text",
	"title": "text"
}
```
5) Set the connection details for your MongoDB instance using `Wgit.set_connection_details` (prior to calling `Wgit::Database#new`)

**Note**: The *text search index* (in step 4) lists all document fields to be searched by MongoDB when calling `Wgit::Database#search`. Therefore, you should append this list with any other fields that you want searched. For example, if you [extend the API](#Extending-The-API) then you might want to search your new fields in the database by adding them to the index above.

### Database Example

The below script shows how to use Wgit's database functionality to index and then search HTML documents stored in the database.

If you're running the code below for yourself, remember to replace the Hash containing the connection details with your own.

```ruby
require 'wgit'
require 'wgit/core_ext' # => Provides the String#to_url and Enumerable#to_urls methods.

# Here we create our own document rather than crawling the web.
# We pass the web page's URL and HTML Strings.
doc = Wgit::Document.new(
  "http://test-url.com".to_url,
  "<html><p>How now brown cow.</p><a href='http://www.google.co.uk'>Click me!</a></html>"
)

# Set your connection details manually (as below) or from the environment using
# Wgit.set_connection_details_from_env
Wgit.set_connection_details(
  'DB_HOST'     => '<host_machine>',
  'DB_PORT'     => '27017',
  'DB_USERNAME' => '<username>',
  'DB_PASSWORD' => '<password>',
  'DB_DATABASE' => '<database_name>',
)

db = Wgit::Database.new # Connects to the database...
db.insert doc

# Searching the database returns documents with matching text 'hits'.
query = "cow"
results = db.search query

doc.url == results.first.url # => true

# Searching the returned documents gives the matching lines of text from that document.
doc.search(query).first # => "How now brown cow."

db.insert doc.external_links

urls_to_crawl = db.uncrawled_urls # => Results will include doc.external_links.
```

## Extending The API

Indexing in Wgit is the means of downloading a web page and serialising parts of the content into accessible document attributes/methods. For example, `Wgit::Document#author` will return you the webpage's HTML tag value of `meta[@name='author']`.

By default, Wgit indexes what it thinks are the most important pieces of information from each webpage. This of course is often not enough given the nature of webpages and their differences from each other. Therefore, there exists a set of ways to extend the default indexing logic.

There are two ways to extend the indexing behaviour of Wgit:

1. Add the elements containing **text** that you're interested in to be indexed.
2. Define custom indexers matched to specific **elements** that you're interested in.

Below describes these two methods in more detail.

### 1. Extending The Default Text Elements

Wgit contains an array of `Wgit::Document.text_elements` which are the default set of webpage elements containing text; which in turn are indexed and accessible via `Wgit::Document#text`.

If you'd like the text of additional webpage elements to be returned from `Wgit::Document#text`, then you can do the following:

```ruby
require 'wgit'
require 'wgit/core_ext'

# Let's add the text of links e.g. <a> tags.
Wgit::Document.text_elements << :a

# Our Document has a link whose's text we're interested in.
doc = Wgit::Document.new(
  "http://some_url.com".to_url,
  "<html><p>Hello world!</p>\
<a href='https://made-up-link.com'>Click this link.</a></html>"
)

# Now all crawled Documents will contain all visible link text in Wgit::Document#text.
doc.text # => ["Hello world!", "Click this link."]
```

**Note**: This only works for textual page content. For more control over the indexed elements themselves, see below.

### 2. Defining Custom Indexers/Elements a.k.a Virtual Attributes

If you want full control over the elements being indexed for your own purposes, then you can define a custom indexer for each type of element that you're interested in.

Once you have the indexed page element, accessed via a `Wgit::Document` instance method, you can do with it as you wish e.g. obtain it's text value or manipulate the element etc. Since the returned types are plain [Nokogiri](https://www.rubydoc.info/github/sparklemotion/nokogiri) objects, you have the full control that the Nokogiri gem gives you.

Here's how to add a custom indexer for a specific page element:

```ruby
require 'wgit'
require 'wgit/core_ext'

# Let's get all the page's table elements.
Wgit::Document.define_extension(
  :tables,                  # Wgit::Document#tables will return the page's tables.
  "//table",                # The xpath to extract the tables.
  singleton: false,         # True returns the first table found, false returns all.
  text_content_only: false, # True returns one or more Strings of the tables text,
                            # false returns the tables as Nokogiri objects (see below).
) do |tables|
  # Here we can manipulate the object(s) before they're set as Wgit::Document#tables.
end

# Our Document has a table which we're interested in.
doc = Wgit::Document.new(
  "http://some_url.com".to_url,
  "<html><p>Hello world!</p>\
<table><th>Header Text</th><th>Another Header</th></table></html>"
)

# Call our newly defined method to obtain the table data we're interested in.
tables = doc.tables

# Both the collection and each table within the collection are plain Nokogiri objects.
tables.class        # => Nokogiri::XML::NodeSet
tables.first.class  # => Nokogiri::XML::Element
```

**Extension Notes**:

- Any links should be mapped into `Wgit::Url` objects; Url's are treated as Strings when being inserted into the database.
- Any object (like a Nokogiri object) will not be inserted into the database, its up to you to map each object into a native type e.g. `Boolean, Array` etc.

## Caveats

Below are some points to keep in mind when using Wgit:

- All `Wgit::Url`'s must be prefixed with an appropiate protocol e.g. `https://`

## Executable

Currently there is no executable provided with Wgit, however...

In future versions of Wgit, an executable will be packaged with the gem. The executable will provide a `pry` console with the `wgit` gem already loaded. Using the console, you'll easily be able to index and search the web without having to write your own scripts.

This executable will be very similar in nature to `./bin/console` which is currently used only for development and isn't packaged as part of the `wgit` gem.

## Development

The current road map is rudimentally listed in the [TODO.txt](https://github.com/michaeltelford/wgit/blob/master/TODO.txt) file.

For a full list of available Rake tasks, run `bundle exec rake help`. The most commonly used tasks are listed below...

After checking out the repo, run `./bin/setup` to install dependencies (requires `bundler`). Then, run `bundle exec rake test` to run the tests. You can also run `./bin/console` for an interactive REPL that will allow you to experiment with the code.

To generate code documentation run `bundle exec yard doc`. To browse the generated documentation run `bundle exec yard server -r`.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, see the *Gem Publishing Checklist* section of the `TODO.txt` file.

## Contributing

Bug reports and pull requests are welcome on [GitHub](https://github.com/michaeltelford/wgit).

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
