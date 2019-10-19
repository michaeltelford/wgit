# Wgit

[![Inline gem version](https://badge.fury.io/rb/wgit.svg)](https://rubygems.org/gems/wgit)
[![Inline downloads](https://img.shields.io/gem/dt/wgit)](https://rubygems.org/gems/wgit)
[![Inline build](https://travis-ci.org/michaeltelford/wgit.svg?branch=master)](https://travis-ci.org/michaeltelford/wgit)
[![Inline docs](http://inch-ci.org/github/michaeltelford/wgit.svg?branch=master)](http://inch-ci.org/github/michaeltelford/wgit)
[![Inline code quality](https://api.codacy.com/project/badge/Grade/d5a0de62e78b460997cb8ce1127cea9e)](https://www.codacy.com/app/michaeltelford/wgit?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=michaeltelford/wgit&amp;utm_campaign=Badge_Grade)

---

Wgit is a Ruby gem similar in nature to GNU's `wget` tool. It provides an easy to use API for programmatic URL parsing, HTML indexing and searching.

Fundamentally, Wgit is a HTTP indexer/scraper which crawls URL's to retrieve and serialise their page contents for later use. You can use Wgit to copy entire websites if required. Wgit also provides a means to search indexed documents stored in a database. Therefore, this library provides the main components of a WWW search engine. The Wgit API is easily extended allowing you to pull out the parts of a webpage that are important to you, the code snippets or tables for example. As Wgit is a library, it supports many different use cases including data mining, analytics, web indexing and URL parsing to name a few.

Check out this [example application](https://search-engine-rb.herokuapp.com) - a search engine (see its [repository](https://github.com/michaeltelford/search_engine)) built using Wgit and Sinatra, deployed to Heroku. Heroku's free tier is used so the initial page load may be slow. Try searching for "Ruby" or something else that's Ruby related.

## Table Of Contents

1. [Installation](#Installation)
2. [Basic Usage](#Basic-Usage)
3. [Documentation](#Documentation)
4. [Practical Examples](#Practical-Examples)
5. [Database Example](#Database-Example)
6. [Extending The API](#Extending-The-API)
7. [Caveats](#Caveats)
8. [Executable](#Executable)
9. [Change Log](#Change-Log)
10. [License](#License)
11. [Contributing](#Contributing)
12. [Development](#Development)

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

```ruby
require 'wgit'

crawler = Wgit::Crawler.new # Uses typhoeus -> libcurl underneath. It's fast!
url = Wgit::Url.new 'https://wikileaks.org/What-is-Wikileaks.html'

doc = crawler.crawl url # Or use #crawl_site(url) { |doc| ... } etc.

doc.class # => Wgit::Document
doc.class.public_instance_methods(false).sort # => [
# :==, :[], :author, :base, :base_url, :crawl_duration, :css, :date_crawled, :doc, :empty?,
# :external_links, :external_urls, :html, :internal_absolute_links, :internal_absolute_urls,
# :internal_links, :internal_urls, :keywords, :links, :score, :search, :search!, :size,
# :statistics, :stats, :text, :title, :to_h, :to_json, :url, :xpath
# ]

doc.url   # => "https://wikileaks.org/What-is-Wikileaks.html"
doc.title # => "WikiLeaks - What is WikiLeaks"
doc.stats # => {
          #   :url=>44, :html=>28133, :title=>17, :keywords=>0,
          #   :links=>35, :text_snippets=>67, :text_bytes=>13735
          # }
doc.links # => ["#submit_help_contact", "#submit_help_tor", "#submit_help_tips", ...]
doc.text  # => ["The Courage Foundation is an international organisation that <snip>", ...]

results = doc.search 'corruption' # Searches doc.text for the given query.
results.first # => "ial materials involving war, spying and corruption.
              #     It has so far published more"
```

## Documentation

100% of Wgit's code is documented using [YARD](https://yardoc.org/), deployed to [Rubydocs](https://www.rubydoc.info/gems/wgit). This greatly benefits developers in using Wgit in their own programs. Another good source of information (as to how the library behaves) are the tests. Also, see the [Practical Examples](#Practical-Examples) section below for real working examples of Wgit in action.

## Practical Examples

Below are some practical examples of Wgit in use. You can copy and run the code for yourself.

### WWW HTML Indexer

See the `Wgit::Indexer#index_www` documentation and source code for an already built example of a WWW HTML indexer. It will crawl any external url's (in the database) and index their HTML for later use, be it searching or otherwise. It will literally crawl the WWW forever if you let it!

See the [Database Example](#Database-Example) for information on how to configure a database for use with Wgit.

### Website Downloader

Wgit uses itself to download and save fixture webpages to disk (used in tests). See the script [here](https://github.com/michaeltelford/wgit/blob/master/test/mock/save_site.rb) and edit it for your own purposes.

### Broken Link Finder

The `broken_link_finder` gem uses Wgit under the hood to find and report a website's broken links. Check out its [repository](https://github.com/michaeltelford/broken_link_finder) for more details.

### CSS Indexer

The below script downloads the contents of the first css link found on Facebook's index page.

```ruby
require 'wgit'
require 'wgit/core_ext' # Provides the String#to_url and Enumerable#to_urls methods.

crawler = Wgit::Crawler.new
url = 'https://www.facebook.com'.to_url

doc = crawler.crawl url

# Provide your own xpath (or css selector) to search the HTML using Nokogiri underneath.
hrefs = doc.xpath "//link[@rel='stylesheet']/@href"

hrefs.class # => Nokogiri::XML::NodeSet
href = hrefs.first.value # => "https://static.xx.fbcdn.net/rsrc.php/v3/y1/l/0,cross/NvZ4mNTW3Fd.css"

css = crawler.crawl href.to_url
css[0..50] # => "._3_s0._3_s0{border:0;display:flex;height:44px;min-"
```

### Keyword Indexer (SEO Helper)

The below script downloads the contents of several webpages and pulls out their keywords for comparison. Such a script might be used by marketeers for search engine optimisation (SEO) for example.

```ruby
require 'wgit'
require 'wgit/core_ext' # => Provides the String#to_url and Enumerable#to_urls methods.

my_pages_keywords = ['Everest', 'mountaineering school', 'adventure']
my_pages_missing_keywords = []

competitor_urls = [
  'http://altitudejunkies.com',
  'http://www.mountainmadness.com',
  'http://www.adventureconsultants.com'
].to_urls

crawler = Wgit::Crawler.new

crawler.crawl(*competitor_urls) do |doc|
  # If there are keywords present in the web document.
  if doc.keywords.respond_to? :-
    puts "The keywords for #{doc.url} are: \n#{doc.keywords}\n\n"
    my_pages_missing_keywords.concat(doc.keywords - my_pages_keywords)
  end
end

if my_pages_missing_keywords.empty?
  puts 'Your pages are missing no keywords, nice one!'
else
  puts 'Your pages compared to your competitors are missing the following keywords:'
  puts my_pages_missing_keywords.uniq
end
```

## Database Example

The next example requires a configured database instance. Currently the only supported DBMS is MongoDB. See [MongoDB Atlas](https://www.mongodb.com/cloud/atlas) for a free (small) account or provide your own MongoDB instance.

`Wgit::Database` provides a light wrapper of logic around the `mongo` gem allowing for simple database interactivity and object serialisation. Using Wgit you can index webpages, store them in a database and then search through all that's been indexed. The use of a database is entirely optional however and isn't required for crawling or URL parsing etc.

The following versions of MongoDB are supported:

| Gem      | Database   |
| -------- | ---------- |
| ~> 2.9.0 | ~> 4.0.0   |

### Data Model

The data model for Wgit is deliberately simplistic. The MongoDB collections consist of:

| Collection  | Purpose                                                |
| ----------- | ------------------------------------------------------ |
| `urls`      | Used to store URL's to be crawled at a later date      |
| `documents` | Used to store web documents after they've been crawled |

Wgit provides respective Ruby classes for each collection object, allowing for serialisation.

### Configuring MongoDB

Follow the steps below to configure MongoDB for use with Wgit. This is only needed if you want to read/write database records.

1) Create collections for: `urls` and `documents`.
2) Add a [*unique index*](https://docs.mongodb.com/manual/core/index-unique/) for the `url` field in **both** collections.
3) Enable `textSearchEnabled` in MongoDB's configuration (if not already so).
4) Create a [*text search index*](https://docs.mongodb.com/manual/core/index-text/#index-feature-text) for the `documents` collection using:
```json
{
  "text": "text",
  "author": "text",
  "keywords": "text",
  "title": "text"
}
```

**Note**: The *text search index* (in step 4) lists all document fields to be searched by MongoDB when calling `Wgit::Database#search`. Therefore, you should append this list with any other fields that you want searched. For example, if you [extend the API](#Extending-The-API) then you might want to search your new fields in the database by adding them to the index above.

### Code Example

The below script shows how to use Wgit's database functionality to index and then search HTML documents stored in the database. If you're running the code for yourself, remember to replace the database [connection string](https://docs.mongodb.com/manual/reference/connection-string/) with your own.

```ruby
require 'wgit'

### CONNECT TO THE DATABASE ###

# In the absence of a connection string parameter, ENV['WGIT_CONNECTION_STRING'] will be used.
db = Wgit::Database.connect '<your_connection_string>'

### SEED SOME DATA ###

# Here we create our own document rather than crawling the web (which works in the same way).
# We provide the web page's URL and HTML Strings.
doc = Wgit::Document.new(
  'http://test-url.com',
  "<html><p>How now brown cow.</p><a href='http://www.google.co.uk'>Click me!</a></html>"
)
db.insert doc

### SEARCH THE DATABASE ###

# Searching the database returns Wgit::Document's which have fields containing the query.
query = 'cow'
results = db.search query

# By default, the MongoDB ranking applies i.e. results.first has the most hits.
# Because results is an Array of Wgit::Document's, we can custom sort/rank e.g.
# `results.sort_by!(&:crawl_duration)` ranks via page load times with results.first being the fastest.
# Any Wgit::Document attribute can be used, including those you define yourself by extending the API.

top_result = results.first
top_result.class           # => Wgit::Document
doc.url == top_result.url  # => true

### PULL OUT THE BITS THAT MATCHED OUR QUERY ###

# Searching each result gives the matching text snippets from that Wgit::Document.
top_result.search(query).first # => "How now brown cow."

### SEED URLS TO BE CRAWLED LATER ###

db.insert top_result.external_links
urls_to_crawl = db.uncrawled_urls # => Results will include top_result.external_links.
```

## Extending The API

Document serialising in Wgit is the means of downloading a web page and serialising parts of its content into accessible document attributes/methods. For example, `Wgit::Document#author` will return you the webpage's HTML element value of `meta[@name='author']`.

By default, Wgit serialises what it thinks are the most important pieces of information from each webpage. This of course is often not enough given the nature of webpages and their differences from each other. Therefore, there exists a set of ways to extend the default serialising logic.

There are two ways to extend the Document serialising behaviour of Wgit:

1. Add the elements containing **text** that you're interested in to be serialised.
2. Define custom serialisers matched to specific **elements** that you're interested in.

Below describes these two methods in more detail.

### 1. Extending The Default Text Elements

Wgit contains an array of `Wgit::Document.text_elements` which are the default set of HTML elements containing text; which in turn are serialised to have their text accessible via `Wgit::Document#text`.

The below code example shows how to extend the text serialised from a webpage; in doing so making the text accessible to methods such as `Wgit::Document#text` and `Wgit::Document#search` etc.

```ruby
require 'wgit'

# Let's add the text of links e.g. <a> tags.
Wgit::Document.text_elements << :a

# Our Document has a link whose's text we're interested in.
doc = Wgit::Document.new(
  'http://some_url.com',
  "<html><p>Hello world!</p><a href='https://made-up-link.com'>Click this link.</a></html>"
)

# Now crawled Documents will contain all visible link text.
doc.text           # => ["Hello world!", "Click this link."]
doc.search('link') # => ["Click this link."]
```

**Note**: This only works for textual page content. For more control over the serialised elements themselves, see below.

### 2. Defining Custom Serialisers Via Document Extensions

If you want full control over the elements being serialised for your own purposes, then you can define a custom serialiser for each type of element that you're interested in.

Once the page element has been serialised, accessed via a `Wgit::Document` instance method, you can do with it as you wish e.g. obtain it's text value or manipulate the element etc. Since you can choose to return text or plain [Nokogiri](https://www.rubydoc.info/github/sparklemotion/nokogiri) objects, you have the full control that the Nokogiri gem gives you.

Here's how to add a Document extension to serialise a specific page element:

```ruby
require 'wgit'

# Let's get all the page's table elements.
Wgit::Document.define_extension(
  :tables,                  # Wgit::Document#tables will return the page's tables.
  '//table',                # The xpath to extract the tables.
  singleton: false,         # True returns the first table found, false returns all.
  text_content_only: false, # True returns one or more Strings of the tables text,
                            # false returns the tables as Nokogiri objects (see below).
) do |tables|
  # Here we can manipulate the object(s) before they're set as Wgit::Document#tables.
end

# Our Document has a table which we're interested in.
doc = Wgit::Document.new(
  'http://some_url.com',
  <<~HTML
  <html>
    <p>Hello world! Welcome to my site.</p>
    <table>
      <tr><th>Name</th><th>Age</th></tr>
      <tr><td>Socrates</td><td>101</td></tr>
      <tr><td>Plato</td><td>106</td></tr>
    </table>
    <p>I hope you enjoyed your visit :-)</p>
  </html>
  HTML
)

# Call our newly defined method to obtain the table data we're interested in.
tables = doc.tables

# Both the collection and each table within the collection are plain Nokogiri objects.
tables.class        # => Nokogiri::XML::NodeSet
tables.first.class  # => Nokogiri::XML::Element

# Notice the Document's stats now include our 'tables' extension.
doc.stats # => {
#   :url=>19, :html=>242, :links=>0, :text_snippets=>2, :text_bytes=>65, :tables=>1
# }
```

**Note**: Wgit uses Document extensions to provide much of it's core serialising functionality, providing access to a webpage's text or links for example. These [default Document extensions](https://github.com/michaeltelford/wgit/blob/master/lib/wgit/document_extensions.rb) provide examples for your own.

**Extension Notes**:

- It's recommended that URL's be mapped into `Wgit::Url` objects. Url's are treated as Strings when being inserted into the database.
- A `Wgit::Document` extension once initialised will become a Document instance variable, meaning that it will be inserted into the Database if it's a primitive type e.g. `String`, `Array` etc. Plain ole Ruby objects won't be inserted.
- Once inserted into the Database, you can search a `Wgit::Document`'s extension attributes by updating the Database's *text search index*. See the [Database Example](#Database-Example) for more information.

## Caveats

Below are some points to keep in mind when using Wgit:

- All absolute `Wgit::Url`'s must be prefixed with an appropiate protocol e.g. `https://` etc.
- By default, up to 5 URL redirects will be followed; this is configurable however.
- IRI's (URL's containing non ASCII characters) **are** supported and will be normalised/escaped prior to being crawled.

## Executable

Currently there is no executable provided with Wgit, however...

In future versions of Wgit, an executable will be packaged with the gem. The executable will provide a `pry` console with the `wgit` gem already loaded. Using the console, you'll easily be able to index and search the web without having to write your own scripts.

This executable will be similar in nature to `./bin/console` which is currently used for development and isn't packaged as part of the `wgit` gem.

## Change Log

See the [CHANGELOG.md](https://github.com/michaeltelford/wgit/blob/master/CHANGELOG.md) for differences (including any breaking changes) between releases of Wgit.

## License

The gem is available as open source under the terms of the MIT License. See [LICENSE.txt](https://github.com/michaeltelford/wgit/blob/master/LICENSE.txt) for more details.

## Contributing

Bug reports and feature requests are welcome on [GitHub](https://github.com/michaeltelford/wgit/issues). Just raise an issue, checking it doesn't already exist.

The current road map is rudimentally listed in the [TODO.txt](https://github.com/michaeltelford/wgit/blob/master/TODO.txt) file. Maybe your feature request is already there?

Before you consider making a contribution, check out [CONTRIBUTING.md](https://github.com/michaeltelford/wgit/blob/master/CONTRIBUTING.md).

## Development

For a full list of available Rake tasks, run `bundle exec rake help`. The most commonly used tasks are listed below...

After checking out the repo, run `./bin/setup`. Then, `bundle exec rake test` to run the tests. You can also run `bundle exec rake console` for an interactive (`pry`) REPL that will allow you to experiment with the code.

To generate code documentation run `bundle exec yardoc`. To browse the generated documentation in a browser run `bundle exec yard server -r`. You can also use the `yri` command line tool e.g. `yri Wgit::Crawler#crawl_site` etc.

To install this gem onto your local machine, run `bundle exec rake install`.
