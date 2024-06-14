require_relative "helpers/test_helper"

# Test class which includes the Wgit::DSL for testing with.
class TestClass
  include Wgit::DSL
end

# Test class for the Wgit Database.adapter_class accessor methods.
# This class should also test any Wgit code that calls:
# `Wgit::Database.adapter_class.new`; which ensures changing adapters works.
class TestDatabaseAdapter < TestHelper
  # Runs before every test.
  def setup; end

  # Runs after every test.
  def teardown
    # Reset the database adapter back to the default.
    Wgit::Database.adapter_class = Wgit::Database::DEFAULT_ADAPTER_CLASS
  end

  def test_adapter_class__default
    assert_equal Wgit::Database::DEFAULT_ADAPTER_CLASS, Wgit::Database.adapter_class
  end

  def test_adapter_class__accessor
    Wgit::Database.adapter_class = Wgit::Database::InMemory

    assert_equal Wgit::Database::InMemory, Wgit::Database.adapter_class
  end

  def test_adapter_class__indexer
    Wgit::Database.adapter_class = Wgit::Database::InMemory
    indexer = Wgit::Indexer.new

    assert_equal Wgit::Database::InMemory, indexer.db.class
  end

  def test_adapter_class__dsl
    Wgit::Database.adapter_class = Wgit::Database::InMemory
    test_class = TestClass.new

    assert_equal Wgit::Database::InMemory, test_class.send(:get_db).class
  end
end
