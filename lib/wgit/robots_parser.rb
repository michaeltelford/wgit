# frozen_string_literal: true

module Wgit
  # The RobotsParser class handles parsing and processing of a web servers
  # robots.txt file.
  class RobotsParser
    include Wgit::Assertable

    # Key representing the start of a comment.
    KEY_COMMENT    = "#"
    # Key value separator used in robots.txt files.
    KEY_SEPARATOR  = ":"
    # Key representing a user agent.
    KEY_USER_AGENT = "User-agent"
    # Key representing an allow URL rule.
    KEY_ALLOW      = "Allow"
    # Key representing a disallow URL rule.
    KEY_DISALLOW   = "Disallow"

    # Value representing the Wgit user agent.
    USER_AGENT_WGIT = :wgit
    # Value representing any user agent including Wgit.
    USER_AGENT_ANY  = :*

    # Value representing any and all paths.
    PATHS_ALL = %w[/ *].freeze

    # Hash containing the user-agent allow/disallow URL rules. Looks like:
    #   allow_paths:    ["/"]
    #   disallow_paths: ["/accounts", ...]
    attr_reader :rules

    # Initializes and returns a Wgit::RobotsParser instance having parsed the
    # robot.txt contents.
    #
    # @param contents [String, #to_s] The contents of the robots.txt file to be
    #   parsed.
    def initialize(contents)
      @rules = {
        allow_paths: Set.new,
        disallow_paths: Set.new
      }

      assert_respond_to(contents, :to_s)
      parse(contents.to_s)
    end

    # Overrides String#inspect to shorten the printed output of a Parser.
    #
    # @return [String] A short textual representation of this Parser.
    def inspect
      "#<Wgit::RobotsParser has_rules=#{rules?} no_index=#{no_index?}>"
    end

    # Returns the allow paths/rules for this parser's robots.txt contents.
    #
    # @return [Array<String>] The allow paths/rules to follow.
    def allow_paths
      @rules[:allow_paths].to_a
    end

    # Returns the disallow paths/rules for this parser's robots.txt contents.
    #
    # @return [Array<String>] The disallow paths/rules to follow.
    def disallow_paths
      @rules[:disallow_paths].to_a
    end

    # Returns whether or not there are rules applying to Wgit.
    #
    # @return [Boolean] True if there are rules for Wgit to follow, false
    #   otherwise.
    def rules?
      allow_rules? || disallow_rules?
    end

    # Returns whether or not there are allow rules applying to Wgit.
    #
    # @return [Boolean] True if there are allow rules for Wgit to follow,
    #   false otherwise.
    def allow_rules?
      @rules[:allow_paths].any?
    end

    # Returns whether or not there are disallow rules applying to Wgit.
    #
    # @return [Boolean] True if there are disallow rules for Wgit to follow,
    #   false otherwise.
    def disallow_rules?
      @rules[:disallow_paths].any?
    end

    # Returns whether or not Wgit is banned from indexing this site.
    #
    # @return [Boolean] True if Wgit should not index this site, false
    #   otherwise.
    def no_index?
      @rules[:disallow_paths].any? { |path| PATHS_ALL.include?(path) }
    end

    private

    # Parses the file contents and sets @rules.
    def parse(contents)
      user_agents = []
      new_block = false

      contents.split("\n").each do |line|
        line.strip!
        next if line.empty? || line.start_with?(KEY_COMMENT)

        # A user agent block is denoted by N User-agent's followed by N
        # Allow/Disallow's. After which a new block is formed from scratch.
        if start_with_any_case?(line, KEY_USER_AGENT)
          if new_block
            user_agents = []
            new_block = false
          end
          user_agents << remove_key(line, KEY_USER_AGENT).downcase.to_sym
        else
          new_block = true
        end

        if start_with_any_case?(line, KEY_ALLOW)
          append_allow_rule(user_agents, line)
        elsif start_with_any_case?(line, KEY_DISALLOW)
          append_disallow_rule(user_agents, line)
        elsif !start_with_any_case?(line, KEY_USER_AGENT)
          Wgit.logger.debug("Skipping unsupported robots.txt line: #{line}")
        end
      end
    end

    # Implements start_with? but case insensitive.
    def start_with_any_case?(str, prefix)
      str.downcase.start_with?(prefix.downcase)
    end

    # Returns line with key removed (if present). Otherwise line is returned
    # as given.
    def remove_key(line, key)
      return line unless start_with_any_case?(line, key)
      return line unless line.count(KEY_SEPARATOR) == 1

      segs = line.split(KEY_SEPARATOR)
      return "" if segs.size == 1

      segs.last.strip
    end

    # Don't append * or /, as this means all paths, which is the same as no
    # allow_paths when passed to Wgit::Crawler.
    def append_allow_rule(user_agents, line)
      return unless wgit_user_agent?(user_agents)

      path = remove_key(line, KEY_ALLOW)
      path = parse_special_syntax(path)
      return if PATHS_ALL.include?(path)

      @rules[:allow_paths] << path
    end

    def append_disallow_rule(user_agents, line)
      return unless wgit_user_agent?(user_agents)

      path = remove_key(line, KEY_DISALLOW)
      path = parse_special_syntax(path)
      @rules[:disallow_paths] << path
    end

    def wgit_user_agent?(user_agents)
      user_agents.any? do |agent|
        [USER_AGENT_ANY, USER_AGENT_WGIT].include?(agent.downcase)
      end
    end

    def parse_special_syntax(path)
      # Remove $ e.g. "/blah$" becomes "/blah"
      path = path.gsub("$", "")

      # Remove any inline comments e.g. "/blah # comment" becomes "/blah"
      path = path.split(" #{KEY_COMMENT}").first if path.include?(" #{KEY_COMMENT}")

      # Replace an empty path with * e.g. "Allow: " becomes "Allow: *"
      path = "*" if path.empty?

      path
    end

    alias_method :paths, :rules
    alias_method :banned?, :no_index?
  end
end
