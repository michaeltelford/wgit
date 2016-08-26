# Wgit

Wgit is wget on steroids with an easy to use API.

Wgit is a WWW indexer or 'spider' which crawls URL's and retrieves their page contents for later use. Also included in this package is a means to search indexed documents stored in a database. Therefore this library provides the main components of a WWW search engine. You can also use Wgit to copy entire website's HTML. 

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'wgit'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install wgit

## Usage

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

Below are some practical examples of Wgit in use. 

The below script downloads the contents of Facebook's (index page) first css link. 

```ruby
require 'wgit'
require 'wgit/core_ext' # => Provides the String#to_url method.

crawler = Wgit::Crawler.new
url = "https://www.facebook.com".to_url

doc = crawler.crawl url
css_urls = doc.xpath "//link[@rel='stylesheet']/@href"

css_urls.class # => Nokogiri::XML::NodeSet
css_url = css_urls.first.value # => "https://static.xx.fbcdn.net/rsrc.php/v3/yE/r/uqWZrDdEiFq.css"

css = crawler.crawl css_url.to_url
css[0..50] # => ".UIContentTopper{padding:14px 0 0 17px;margin:50px "
```

The below script downloads the contents of several webpages, pulls out their keywords and compares them.
Such a file might be used by marketeers for SEO optimisation. 

```ruby
#TODO
```

## Executable

Currently there is no executable provided with Wgit, however...

In future versions of Wgit a `wgit` executable will be provided as part of the gem. This executable will provide the capability to crawl a Url from the command line just like wget but you'll be able to do much more like recursively crawl entire sites and easily store the resulting markup in a Database or to a file. 

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake RELEASE[remote]` (remote being the correct Git remote), which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/michaeltelford/wgit.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
