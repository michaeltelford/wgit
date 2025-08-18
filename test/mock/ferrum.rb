require "ferrum"
require_relative "webmock"

# Add any Ferrum (chromium) mocks below.
# The url must match the request url exactly (check the trailing slash).
# The url must also be mocked in fixtures.rb for Crawler#resolve logic.
def mock_pages
  {
    "http://javascript-eval.com/" => fixture("javascript-eval.com")
  }
end

module MockFerrumBrowser
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def new(*args, **kwargs)
      browser = super(*args, **kwargs)

      page = browser.create_page
      page.network.intercept
      page.on(:request) do |request|
        mock_html = mock_pages[request.url]
        if mock_html
          request.respond(
            status: 200,
            headers: { "Content-Type" => "text/html" },
            body: mock_html
          )
        else
          request.continue
        end
      end

      browser
    end
  end
end

Ferrum::Browser.include(MockFerrumBrowser)
