require "minitest/autorun"
require "minitest/pride"
require "byebug"

# Test helper module for unit tests.
module TestHelper
    # Flunk (fail) the test if an exception is thrown.
    def flunk_ex(test)
        yield
    rescue Exception => ex
        test.flunk ex.message
    end
end
