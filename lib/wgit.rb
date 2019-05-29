# Require all Wgit gem code...
require_relative 'wgit/version'
require_relative 'wgit/logger'; Wgit.use_default_logger
require_relative 'wgit/crawler'
require_relative 'wgit/indexer'
require_relative 'wgit/url'
require_relative 'wgit/document'
require_relative 'wgit/utils'
require_relative 'wgit/assertable'
require_relative 'wgit/database/database'
require_relative 'wgit/database/model'
require_relative 'wgit/database/connection_details'
# We don't add core bahaviour by default, it must be an explicit require.
#require_relative 'wgit/core_ext'
