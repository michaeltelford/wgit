# frozen_string_literal: true

# Development script which loads (any code changes), includes modules and
# connects to the database when called/executed.
#
# NOTE: connection_details.rb are not loaded here, they should be required and
# set elsewhere for interacting with the DB prior to loading this file.

load 'lib/wgit/version.rb'
load 'lib/wgit/logger.rb'
load 'lib/wgit/assertable.rb'
load 'lib/wgit/utils.rb'
load 'lib/wgit/url.rb'
load 'lib/wgit/document.rb'
load 'lib/wgit/document_extensions.rb'
load 'lib/wgit/crawler.rb'
load 'lib/wgit/database/model.rb'
load 'lib/wgit/database/database.rb'
load 'lib/wgit/database/database_default_data.rb'
load 'lib/wgit/database/database_helper.rb'
load 'lib/wgit/indexer.rb'
load 'lib/wgit/core_ext.rb'

include Wgit # Remove the name space around code for development purposes.
include Assertable
include DatabaseHelper # Connects to the database.
