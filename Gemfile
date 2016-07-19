source 'https://rubygems.org'

ruby '2.2.2'
# mongo '3.0'

# bundle install of nokogiri or mongo when already installed broke all
# networking until I upgraded my installed version of Ruby, so beware!
gem 'nokogiri'
gem 'mongo'
gem 'net/http' # requires the 'uri' gem within.

group :development do
    gem 'yard'
end

group :test do
    gem 'minitest'
end
