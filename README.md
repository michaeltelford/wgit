# Wgit

[![Inline gem version](https://badge.fury.io/rb/wgit.svg)](https://rubygems.org/gems/wgit)
[![Inline downloads](https://img.shields.io/gem/dt/wgit)](https://rubygems.org/gems/wgit)
[![Inline build](https://travis-ci.org/michaeltelford/wgit.svg?branch=master)](https://travis-ci.org/michaeltelford/wgit)
[![Inline docs](http://inch-ci.org/github/michaeltelford/wgit.svg?branch=master)](http://inch-ci.org/github/michaeltelford/wgit)
[![Inline code quality](https://api.codacy.com/project/badge/Grade/d5a0de62e78b460997cb8ce1127cea9e)](https://www.codacy.com/app/michaeltelford/wgit?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=michaeltelford/wgit&amp;utm_campaign=Badge_Grade)

---

Wgit is a HTML web crawler written in Ruby - it allows you to extract the data you want from the web.

Wgit was primarily designed to crawl static HTML websites to index and search their content - providing the basis of any search engine; but Wgit is suitable for many application domains including:

- URL parsing
- Document content extraction (data mining)
- Crawling entire websites (statistical analysis)

Wgit provides an easy-to-use API and DSL that you can use in your own applications and scripts.

Check out this [demo search engine](https://search-engine-rb.herokuapp.com) - [built](https://github.com/michaeltelford/search_engine) using Wgit and Sinatra - deployed to [Heroku](https://www.heroku.com/). Heroku's free tier is used so the initial page load may be slow. Try searching for "Matz" or something else that's Ruby related.

## Table Of Contents

1. [Usage](#Usage)
2. [Why Wgit?](#Why-Wgit?)
3. [Why Not Wgit?](#Why-Not-Wgit?)
4. [Installation](#Installation)
5. [Documentation](#Documentation)
6. [Executable](#Executable)
7. [License](#License)
8. [Contributing](#Contributing)
9. [Development](#Development)

## Usage

Let's crawl a [quotes website](http://quotes.toscrape.com/) extracting its *quotes* and *authors* using the Wgit DSL:

```ruby
require 'wgit'
require 'json'

include Wgit::DSL

start  'http://quotes.toscrape.com/tag/humor/'
follow "//li[@class='next']/a/@href"

extract :quotes,  "//div[@class='quote']/span[@class='text']", singleton: false
extract :authors, "//div[@class='quote']/span/small",          singleton: false

quotes = []

crawl_site do |doc|
  doc.quotes.zip(doc.authors).each do |arr|
    quotes << {
      quote:  arr.first,
      author: arr.last
    }
  end
end

puts JSON.generate(quotes)
```

The DSL makes it easy to write one off scripts for experimenting with. Wgit's DSL is simply a wrapper around the underlying classes however. For comparison, here is the above example written using the Wgit classes *instead of* the DSL:

```ruby
require 'wgit'
require 'json'

crawler = Wgit::Crawler.new
url     = Wgit::Url.new('http://quotes.toscrape.com/tag/humor/')
quotes  = []

Wgit::Document.define_extractor(:quotes,  "//div[@class='quote']/span[@class='text']", singleton: false)
Wgit::Document.define_extractor(:authors, "//div[@class='quote']/span/small",          singleton: false)

crawler.crawl_site(url, follow: "//li[@class='next']/a/@href") do |doc|
  doc.quotes.zip(doc.authors).each do |arr|
    quotes << {
      quote:  arr.first,
      author: arr.last
    }
  end
end

puts JSON.generate(quotes)
```

But what if we want to crawl and store the content in a database, so that it can be searched? Wgit makes it easy to index and search HTML using [MongoDB](https://www.mongodb.com/):

```ruby
require 'wgit'

include Wgit::DSL

Wgit.logger.level = Logger::WARN

connection_string 'mongodb://user:password@localhost/crawler'
clear_db!

extract :quotes,  "//div[@class='quote']/span[@class='text']", singleton: false
extract :authors, "//div[@class='quote']/span/small",          singleton: false

start  'http://quotes.toscrape.com/tag/humor/'
follow "//li[@class='next']/a/@href"

index_site
search 'prejudice'
```

The `search` call (on the last line) will return and output the results:

```text
Quotes to Scrape
“I am free of all prejudice. I hate everyone equally. ”
http://quotes.toscrape.com/tag/humor/page/2/
```

Using a Mongo DB [client](https://robomongo.org/), we can see that the two webpages have been indexed, along with their extracted *quotes* and *authors*:

![MongoDBClient](https://raw.githubusercontent.com/michaeltelford/wgit/assets/assets/wgit_mongo_index.png)

## Why Wgit?

There are many [other HTML crawlers](https://awesome-ruby.com/#-web-crawling) out there so why use Wgit?

- Wgit has excellent unit testing, 100% documentation coverage and follows [semantic versioning](https://semver.org/) rules.
- Wgit excels at crawling an entire website's HTML out of the box. Many alternative crawlers require you to provide the `xpath` needed to *follow* the next URLs to crawl. Wgit by default, crawls the entire site by extracting its internal links pointing to the same host.
- Wgit allows you to define content *extractors* that will fire on every subsequent crawl; be it a single URL or an entire website. This enables you to focus on the content you want.
- Wgit can index (crawl and store) HTML to a database making it a breeze to build custom search engines. You can also specify which page content gets searched, making the search more meaningful. For example, here's a script that will index the Wgit [wiki](https://github.com/michaeltelford/wgit/wiki) articles:

```ruby
require 'wgit'

ENV['WGIT_CONNECTION_STRING'] = 'mongodb://user:password@localhost/crawler'

wiki = Wgit::Url.new('https://github.com/michaeltelford/wgit/wiki')

# Only index the most recent of each wiki article, ignoring the rest of Github.
opts = {
  allow_paths:    'michaeltelford/wgit/wiki/*',
  disallow_paths: 'michaeltelford/wgit/wiki/*/_history'
}

indexer = Wgit::Indexer.new
indexer.index_site(wiki, opts)
```

## Why Not Wgit?

So why might you not use Wgit, I hear you ask?

- Wgit doesn't allow for webpage interaction e.g. signing in as a user. There are better gems out there for that.
- Wgit (for now) doesn't render/process any Javascript it finds on a crawled document - meaning it may not play well with SPAs.
- Wgit while fast (using `libcurl` for networking etc.), isn't multi-threaded; so each URL gets crawled sequentially. You could hand each crawled document to a worker thread for processing - but if you need concurrent crawling then you might want to consider something else.

## Installation

Only MRI Ruby is tested and supported, but Wgit may work with other Ruby implementations.

Currently, the required MRI Ruby version is:

`~> 2.5` a.k.a. `>= 2.5 && < 3`

### Using Bundler

Add this line to your application's `Gemfile`:

```ruby
gem 'wgit'
```

And then execute:

    $ bundle

### Using RubyGems

    $ gem install wgit

Verify the install by using the executable (to start an REPL session):

    $ wgit

## Documentation

- [Getting Started](https://github.com/michaeltelford/wgit/wiki/Getting-Started)
- [Wiki](https://github.com/michaeltelford/wgit/wiki)
- [Yardocs](https://www.rubydoc.info/github/michaeltelford/wgit/master)
- [CHANGELOG](https://github.com/michaeltelford/wgit/blob/master/CHANGELOG.md)

## Executable

Installing the Wgit gem adds a `wgit` executable to your `$PATH`. The executable launches an interactive REPL session with the Wgit gem already loaded; making it super easy to index and search from the command line without the need for scripts.

The `wgit` executable does the following things (in order):

1. `require wgit`
2. `eval`'s a `.wgit.rb` file (if one exists in either the local or home directory, which ever is found first)
3. Starts an interactive shell (using `pry` if it's installed, or `irb` if not)

The `.wgit.rb` file can be used to seed fixture data or define helper functions for the session. For example, you could define a function which indexes your website for quick and easy searching everytime you start a new session.

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

Wgit uses the [`toys`](https://github.com/dazuma/toys) gem (instead of Rake) for task invocation. For a full list of available tasks a.k.a. tools, run `toys --tools`. You can search for a tool using `toys -s tool_name`. The most commonly used tools are listed below...

Run `toys db` to see a list of database related tools, enabling you to run a Mongo DB instance locally using Docker. Run `toys test` to execute the tests.

To generate code documentation locally, run `toys yardoc`. To browse the docs in a browser run `toys yardoc --serve`. You can also use the `yri` command line tool e.g. `yri Wgit::Crawler#crawl_site` etc.

To install this gem onto your local machine, run `toys install` and follow the prompt.

### Console

You can run `toys console` for an interactive shell using the `./bin/wgit` executable. The `toys setup` task will have created an `.env` and `.wgit.rb` file which get loaded by the executable. You can use the contents of this [gist](https://gist.github.com/michaeltelford/b90d5e062da383be503ca2c3a16e9164) to turn the executable into a development console. It defines some useful functions, fixtures and connects to the database etc. Don't forget to set the `WGIT_CONNECTION_STRING` in the `.env` file.
