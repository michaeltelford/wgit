require_relative 'helpers/test_helper'

# Test class for the Wgit version.
class TestVersion < TestHelper
  # Runs before every test.
  def setup; end

  def test_version_const
    assert_instance_of String, Wgit::VERSION
    assert_equal 2, Wgit::VERSION.count('.')
  end

  def test_version
    assert_equal Wgit::VERSION, Wgit.version
  end

  def test_version_str
    assert_equal "wgit v#{Wgit::VERSION}", Wgit.version_str
  end
end
