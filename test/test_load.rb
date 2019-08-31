# frozen_string_literal: true

require_relative 'helpers/test_helper'

# Test class for the load script (used in dev).
class TestLoad < TestHelper
  # Runs before every test.
  def setup; end

  def test_load
    assert load('load.rb')
    Wgit.logger.level = Logger::WARN
  end
end
