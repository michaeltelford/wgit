require 'webmock'
require 'uri'

include WebMock::API

WebMock.enable!
WebMock.disable_net_connect!

def fixtures_dir
  "test/mock/fixtures".freeze
end

# Return the contents of a fixture HTML file.
def fixture(path)
  path = "#{path}.html" unless path.end_with?('.html')
  file_path = path.start_with?(fixtures_dir) ? path : "#{fixtures_dir}/#{path}"
  File.read(file_path)
end

# Return the default HTML fixture data.
def default_html
  fixture('test_doc')
end

# Stub a single webpage. Stubs both:
# http://blah.com and http://blah.com/ (with trailing slash).
def stub_page(url, status: 200, body: default_html, fixture: nil)
  body = fixture(fixture) if fixture
  alt_url = url.end_with?('/') ? url[0..-2] : "#{url}/"
  stub_request(:get, url).to_return(status: status, body: body)
  stub_request(:get, alt_url).to_return(status: status, body: body)
end

# Stub a single page 301 redirect.
def stub_redirect(from, to)
  stub_request(:get, from).to_return(status: 301, headers: { 'Location': to })
end

# Stub an entire website recursively according to what's saved on the file
# system. Assumes the fixture data exists on disk.
def stub_dir(url, path, dir)
  url  = url[0..-2]  if url.end_with?('/')  # Remove trailing slash.
  path = path[0..-2] if path.end_with?('/') #   "
  dir  = dir[0..-2]  if dir.end_with?('/')  #   "

  url  += "/#{dir}" unless URI(url).host == dir
  path += "/#{dir}"

  objects = Dir["#{path}/*"]
  files = objects.
    select { |obj| File.file?(obj) }.
    reject { |f| f.end_with?('index.html') }.
    map { |f| f.end_with?('.html') ? f[0..-6] : f }
  dirs = objects.select { |obj| File.directory?(obj) }

  files.each { |f| stub_page("#{url}/#{f.split('/').last}", fixture: f) }
  dirs.each  { |d| stub_dir(url, path, d.split('/').last) }
end

# Stub all single webpages and full websites from the fixtures directory.
def stub_fixtures(pages, sites)
  pages.each do |url|
    path = URI(url).host
    stub_page(url, fixture: path)
  end

  sites.each do |url|
    dir = URI(url).host
    stub_page(url, fixture: "#{dir}/index")
    stub_dir(url, 'test/mock/fixtures', dir)
  end
end
