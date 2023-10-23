# frozen_string_literal: true

# Development script which loads (all changes to) the code when called.
# Note this script doesn't establish a connection to the database.

load 'lib/wgit/version.rb'
load 'lib/wgit/logger.rb'
load 'lib/wgit/assertable.rb'
load 'lib/wgit/utils.rb'
load 'lib/wgit/url.rb'
load 'lib/wgit/document.rb'
load 'lib/wgit/document_extractors.rb'
load 'lib/wgit/crawler.rb'
load 'lib/wgit/database/model.rb'
load 'lib/wgit/database/database.rb'
load 'lib/wgit/robots_parser.rb'
load 'lib/wgit/indexer.rb'
load 'lib/wgit/dsl.rb'
load 'lib/wgit/base.rb'
load 'lib/wgit/core_ext.rb'

include Wgit # Remove the name space around code (for development purposes).
include DSL
include Assertable
