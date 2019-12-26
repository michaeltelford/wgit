# Wgit

[![Inline gem version](https://badge.fury.io/rb/wgit.svg)](https://rubygems.org/gems/wgit)
[![Inline downloads](https://img.shields.io/gem/dt/wgit)](https://rubygems.org/gems/wgit)
[![Inline build](https://travis-ci.org/michaeltelford/wgit.svg?branch=master)](https://travis-ci.org/michaeltelford/wgit)
[![Inline docs](http://inch-ci.org/github/michaeltelford/wgit.svg?branch=master)](http://inch-ci.org/github/michaeltelford/wgit)
[![Inline code quality](https://api.codacy.com/project/badge/Grade/d5a0de62e78b460997cb8ce1127cea9e)](https://www.codacy.com/app/michaeltelford/wgit?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=michaeltelford/wgit&amp;utm_campaign=Badge_Grade)

---

Wgit is a Ruby gem similar in nature to GNU's `wget` tool. It provides an easy to use API for programmatic URL parsing, HTML indexing and searching.

Fundamentally, Wgit is a HTTP indexer/scraper which crawls URL's to retrieve and serialise their page contents for later use. You can use Wgit to copy entire websites if required. Wgit also provides a means to search indexed documents stored in a database. Therefore, this library provides the main components of a WWW search engine. The Wgit API is easily extended allowing you to pull out the parts of a webpage that are important to you, the code snippets or tables for example. As Wgit is a library, it supports many different use cases including data mining, analytics, web indexing and URL parsing to name a few.

Check out this [demo application](https://search-engine-rb.herokuapp.com) - a search engine (see its [repository](https://github.com/michaeltelford/search_engine)) built using Wgit and Sinatra, deployed to Heroku. Heroku's free tier is used so the initial page load may be slow. Try searching for "Ruby" or something else that's Ruby related.

Continue reading the rest of this `README` for more information on Wgit. When you've finished, check out the [wiki](https://github.com/michaeltelford/wgit/wiki).

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

Currently, the required Ruby version is:

`~> 2.5` a.k.a. `>= 2.5 && < 3`

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

crawler = Wgit::Crawler.new # Uses Typhoeus -> libcurl underneath. It's fast!
url = Wgit::Url.new 'https://wikileaks.org/What-is-Wikileaks.html'

doc = crawler.crawl url # Or use #crawl_site(url) { |doc| ... } etc.
crawler.last_response.class # => Wgit::Response is a wrapper for Typhoeus::Response.

doc.class # => Wgit::Document
doc.class.public_instance_methods(false).sort # => [
# :==, :[], :author, :base, :base_url, :content, :css, :doc, :empty?, :external_links,
# :external_urls, :html, :internal_absolute_links, :internal_absolute_urls,
# :internal_links, :internal_urls, :keywords, :links, :score, :search, :search!,
# :size, :statistics, :stats, :text, :title, :to_h, :to_json, :url, :xpath
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

100% of Wgit's code is documented using [YARD](https://yardoc.org/), deployed to [rubydoc.info](https://www.rubydoc.info/github/michaeltelford/wgit/master). This greatly benefits developers in using Wgit in their own programs. Another good source of information (as to how the library behaves) are the [tests](https://github.com/michaeltelford/wgit/tree/master/test). Also, see the [Practical Examples](#Practical-Examples) section below for real working examples of Wgit in action.

## Practical Examples

Below are some practical examples of Wgit in use. You can copy and run the code for yourself (it's all been tested).

In addition to the practical examples below, the [wiki](https://github.com/michaeltelford/wgit/wiki) contains a useful 'How To' section with more specific usage of Wgit. You should finish reading this `README` first however.

### WWW HTML Indexer

See the [`Wgit::Indexer#index_www`](https://www.rubydoc.info/github/michaeltelford/wgit/master/Wgit%2Eindex_www) documentation and source code for an already built example of a WWW HTML indexer. It will crawl any external URL's (in the database) and index their HTML for later use, be it searching or otherwise. It will literally crawl the WWW forever if you let it!

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

The next example requires a configured database instance. The use of a database for Wgit is entirely optional however and isn't required for crawling or URL parsing etc. A database is only needed when indexing (inserting crawled data into the database).

Currently the only supported DBMS is MongoDB. See [MongoDB Atlas](https://www.mongodb.com/cloud/atlas) for a (small) free account or provide your own MongoDB instance. Take a look at this [Docker Hub image](https://hub.docker.com/r/michaeltelford/mongo-wgit) for an already built example of a `mongo` image configured for use with Wgit; the source of which can be found in the [`./docker`](https://github.com/michaeltelford/wgit/tree/master/docker) directory of this repository.

[`Wgit::Database`](https://www.rubydoc.info/github/michaeltelford/wgit/master/Wgit/Database) provides a light wrapper of logic around the `mongo` gem allowing for simple database interactivity and object serialisation. Using Wgit you can index webpages, store them in a database and then search through all that's been indexed; quickly and easily.

### Versioning

The following versions of MongoDB are currently supported:

| Gem    | Database |
| ------ | -------- |
| ~> 2.9 | ~> 4.0   |

### Data Model

The data model for Wgit is deliberately simplistic. The MongoDB collections consist of:

| Collection  | Purpose                                         |
| ----------- | ----------------------------------------------- |
| `urls`      | Stores URL's to be crawled at a later date      |
| `documents` | Stores web documents after they've been crawled |

Wgit provides respective Ruby classes for each collection object, allowing for serialisation.

### Configuring MongoDB

Follow the steps below to configure MongoDB for use with Wgit. This is only required if you want to read/write database records using your own (manually configured) instance of Mongo DB.

1) Create collections for: `urls` and `documents`.
2) Add a [*unique index*](https://docs.mongodb.com/manual/core/index-unique/) for the `url` field in **both** collections using:

| Collection  | Fields              | Options             |
| ----------- | ------------------- | ------------------- |
| `urls`      | `{ "url" : 1 }`     | `{ unique : true }` |
| `documents` | `{ "url.url" : 1 }` | `{ unique : true }` |

3) Enable `textSearchEnabled` in MongoDB's configuration (if not already so - it's typically enabled by default).
4) Create a [*text search index*](https://docs.mongodb.com/manual/core/index-text/#index-feature-text) for the `documents` collection using:
```json
{
  "text": "text",
  "author": "text",
  "keywords": "text",
  "title": "text"
}
```

**Note**: The *text search index* lists all document fields to be searched by MongoDB when calling `Wgit::Database#search`. Therefore, you should append this list with any other fields that you want searched. For example, if you [extend the API](#Extending-The-API) then you might want to search your new fields in the database by adding them to the index above.

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
# `results.sort_by! { |doc| doc.url.crawl_duration }` ranks via page load times with
# results.first being the fastest. Any Wgit::Document attribute can be used, including
# those you define yourself by extending the API.

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

Document serialising in Wgit is the means of downloading a web page and extracting parts of its content into accessible document attributes/methods. For example, `Wgit::Document#author` will return you the webpage's HTML element value of `meta[@name='author']`.

By default, Wgit serialises what it thinks are the most important pieces of information from each webpage. This of course is often not enough given the nature of the WWW and the differences from one webpage to the next. Therefore, there exists a way to extend the default serialising logic.

### Extracting Specific Page Elements via Document Extensions

You can define a Document extension for each HTML element(s) that you want to extract into a `Wgit::Document` instance variable, equipped with a getter method. Once an extension is defined, any crawled Documents will contain your extracted content.

Once the page element has been serialised, you can do with it as you wish e.g. obtain it's text value or manipulate the element etc. Since you can choose to return the element's text or the [Nokogiri](https://www.rubydoc.info/github/sparklemotion/nokogiri) object, you have the full power that the Nokogiri gem gives you.

Here's how to add a Document extension to serialise a specific page element:

```ruby
require 'wgit'

# Let's get all the page's <table> elements.
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
tables.class       # => Nokogiri::XML::NodeSet
tables.first.class # => Nokogiri::XML::Element

# Notice the Document's stats now include our 'tables' extension.
doc.stats # => {
#   :url=>19, :html=>242, :links=>0, :text_snippets=>2, :text_bytes=>65, :tables=>1
# }
```

Wgit uses Document extensions to provide much of it's core serialising functionality, providing access to a webpage's text or links for example. These [default Document extensions](https://github.com/michaeltelford/wgit/blob/master/lib/wgit/document_extensions.rb) provide examples for your own.

See the [Wgit::Document.define_extension](https://www.rubydoc.info/github/michaeltelford/wgit/master/Wgit%2FDocument.define_extension) docs for more information.

**Extension Notes**:

- It's recommended that URL's be mapped into `Wgit::Url` objects. `Wgit::Url`'s are treated as Strings when being inserted into the database.
- A `Wgit::Document` extension (once initialised) will become a Document instance variable, meaning that the value will be inserted into the Database if it's a primitive type e.g. `String`, `Array` etc. Complex types e.g. Ruby objects won't be inserted. It's up to you to ensure the data you want inserted, can be inserted.
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

### Gem Versioning

The `wgit` gem follows these versioning rules:

- The version format is `MAJOR.MINOR.PATCH` e.g. `0.1.0`.
- Since the gem hasn't reached `v1.0.0` yet, slightly different semantic versioning rules apply.
- The `PATCH` represents *non breaking changes* while the `MINOR` represents *breaking changes* e.g. updating from version `0.1.0` to `0.2.0` will likely introduce breaking changes necessitating updates to your codebase.
- To determine what changes are needed, consult the `CHANGELOG.md`. If you need help, raise an issue.
- Once `wgit v1.0.0` is released, *normal* [semantic versioning](https://semver.org/) rules will apply e.g. only a `MAJOR` version change should introduce breaking changes.

## License

The gem is available as open source under the terms of the MIT License. See [LICENSE.txt](https://github.com/michaeltelford/wgit/blob/master/LICENSE.txt) for more details.

## Contributing

Bug reports and feature requests are welcome on [GitHub](https://github.com/michaeltelford/wgit/issues). Just raise an issue, checking it doesn't already exist.

The current road map is rudimentally listed in the [Road Map](https://github.com/michaeltelford/wgit/wiki/Road-Map) wiki page. Maybe your feature request is already there?

Before you consider making a contribution, check out [CONTRIBUTING.md](https://github.com/michaeltelford/wgit/blob/master/CONTRIBUTING.md).

## Development

After checking out the repo, run the following commands:

1. `gem install bundler toys`
2. `bundle install --jobs=3`
3. `toys setup`

And you're good to go!

### Tooling

Wgit uses the [`toys`](https://github.com/dazuma/toys) gem (instead of Rake) for task invocation e.g. running the tests etc. For a full list of available tasks AKA tools, run `toys --tools`. You can search for a tool using `toys -s tool_name`. The most commonly used tools are listed below...

Run `toys db` to see a list of database related tools, enabling you to run a Mongo DB instance locally using Docker.

Run `toys test` to execute the tests (or `toys test smoke` for a faster running subset). You can also run `toys console` for an interactive (`pry`) REPL that will allow you to experiment with the code.

To generate code documentation run `toys yardoc`. To browse the generated documentation in a browser run `toys yardoc --serve`. You can also use the `yri` command line tool e.g. `yri Wgit::Crawler#crawl_site` etc.

To install this gem onto your local machine, run `toys install`.
