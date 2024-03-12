# frozen_string_literal: true

require_relative '../url'
require_relative '../document'
require_relative '../logger'
require_relative '../assertable'
require_relative 'model'
require 'logger'
require 'mongo'

module Wgit
  # Module providing a Database connection and CRUD operations for the Url and
  # Document collections.
  module Database
    # Database adapter class for inheriting from by underlying implementation
    # classes.
    class DatabaseAdapter
      include Assertable

      # Initializes a DatabaseAdapter instance.
      def initialize; end
    end
  end
end
