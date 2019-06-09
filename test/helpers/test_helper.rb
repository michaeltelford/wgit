$VERBOSE = nil # Suppress ruby warnings for the test run.

require 'minitest/autorun'
require 'logger'
require 'dotenv'
require 'byebug' # Call 'byebug' anywhere in the code to debug.

require_relative '../mock/fixtures' # Mock HTTP responses.

# Require all code being tested once, in one place.
require_relative '../../lib/wgit'
require_relative '../../lib/wgit/core_ext'
require_relative '../../lib/wgit/database/database_helper'
require_relative '../../lib/wgit/database/database_default_data'

# Remove any unwanted STDOUT noise from the test output.
Wgit.logger.level = Logger::WARN

# Test helper class for unit tests. Should be inherited from by all test cases.
class TestHelper < Minitest::Test
  include Wgit::Assertable

  # Fires everytime this class is subclassed.
  def self.inherited(child)
    # Load any required .env vars e.g. DB connection details.
    Dotenv.load!

    # Set the DB connection details from the ENV.
    load 'lib/wgit/database/connection_details.rb'
    Wgit.set_connection_details_from_env

    # Run the tests.
    super
  end

  # Any helper methods go below, these will be callable from child unit tests.

  # Flunk (fail) the test if an exception is raised in the given block.
  def refute_exception
    yield
  rescue Exception => ex
    flunk ex.message
  end
end
