# frozen_string_literal: true

require_relative "adapters/mongo_db"

module Wgit
  # Module providing a Database connection and CRUD operations for the Url and
  # Document collections that form the Wgit persistence layer.
  module Database
    # The default Database adapter class used by Wgit.
    DEFAULT_ADAPTER_CLASS = Wgit::Database::MongoDB

    # The Database adapter class to be used by Wgit. Set this based on the
    # Database you want to use. The adapter doesn't exist yet? Write your own.
    @adapter_class = DEFAULT_ADAPTER_CLASS

    class << self
      # The Database adapter class to use with Wgit. The adapter you supply
      # should be a subclass of Wgit::Database::DatabaseAdapter and should
      # implement the methods within it, in order to work with Wgit.
      attr_accessor :adapter_class
    end
  end
end
