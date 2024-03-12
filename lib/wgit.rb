# frozen_string_literal: true

require_relative 'wgit/version'
require_relative 'wgit/logger'
require_relative 'wgit/assertable'
require_relative 'wgit/utils'
require_relative 'wgit/url'
require_relative 'wgit/document'
require_relative 'wgit/document_extractors'
require_relative 'wgit/crawler'
require_relative 'wgit/database/model'
require_relative 'wgit/database/database_adapter'
require_relative 'wgit/database/adapters/mongo_db'
require_relative 'wgit/robots_parser'
require_relative 'wgit/indexer'
require_relative 'wgit/dsl'
require_relative 'wgit/base'
# require_relative 'wgit/core_ext' - Must be explicitly required.
