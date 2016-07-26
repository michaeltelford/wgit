# Pinch

Pinch is a WWW indexer or 'spider' which crawls URL's and retrieves their page contents for later use. Also included in this package is a means to search indexed documents stored in a database. Therefore this library provides the main components of a WWW search engine. You can also use Pinch to copy entire websites or web pages' HTML. 

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pinch'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install pinch

## Usage

Below shows an example of API usage in action and gives an idea of how you can use Pinch in your own code.

```ruby
require 'pinch'

crawler = Pinch::Crawler.new
url = Pinch::Url.new "https://wikileaks.org/What-is-Wikileaks.html"

doc = crawler.crawl url
doc.stats # => {:url=>44, :html=>28133, :title=>17, :keywords=>0, :links=>35, :text_length=>67, :text_bytes=>13735}

doc.class # => Pinch::Document
Pinch::Document.instance_methods(false).sort # => [:author, :empty?, :external_links, :html, :internal_full_links, :internal_links, :keywords, :links, :relative_links, :score, :search, :search!, :size, :stats, :text, :title, :to_h, :to_hash, :url, :xpath]

results = doc.search "corruption"
results.first # => "ial materials involving war, spying and corruption. It has so far published more"
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/michaeltelford/pinch.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

