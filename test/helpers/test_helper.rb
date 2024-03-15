# frozen_string_literal: true

$VERBOSE = nil # Suppress ruby warnings during the test run.

require 'maxitest/autorun'
require 'maxitest/threads' # Fail on orphaned test threads.
require 'maxitest/timeout'
require 'logger'
require 'dotenv'
require 'byebug' # Call 'byebug' anywhere in the code to debug.

require_relative '../mock/fixtures' # Mock HTTP responses.
require_relative 'database_test_data'
require_relative 'database_helper'
require_relative 'mongo_db_helper'

# Require all code being tested once, in one place.
require_relative '../../lib/wgit'
require_relative '../../lib/wgit/core_ext'

Maxitest.timeout  = 60           # Fail test after N seconds.
Wgit.logger.level = Logger::WARN # Remove STDOUT noise from test run.

# Test helper class for unit tests. Should be inherited from by all test cases.
class TestHelper < Minitest::Test
  # Fires everytime this class is inherited from.
  def self.inherited(child)
    Dotenv.load # Set the DB connection string from the ENV.
    super       # Run the tests.
  end

  # Any helper methods go below, these will be callable from unit tests.

  # Flunk (fail) the test if an exception is raised by the given block.
  def refute_exception
    yield
  rescue StandardError => e
    flunk e.message
  end
end

# Override type #inspect methods for nicer test failure messages.
class Wgit::Url
  def inspect
    "\"#{to_s}\""
  end
end
