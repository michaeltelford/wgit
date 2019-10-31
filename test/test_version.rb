require_relative 'helpers/test_helper'

# Test class for the Wgit version.
class TestVersion < TestHelper
  # Runs before every test.
  def setup; end

  def test_version_presence
    refute_nil Wgit::VERSION
  end

  def test_version_method
    refute_nil Wgit.version
  end
end
