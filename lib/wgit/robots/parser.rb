# frozen_string_literal: true

require 'set'

# The Robots module handles parsing and processing of a web servers robots.txt file.
module Wgit::Robots
  # The Robots::Parser class handles parsing and processing of a web servers robots.txt file.
  class Parser
    include Wgit::Assertable

    # Key representing a user agent.
    KEY_USER_AGENT = "User-agent".freeze
    # Key representing an allow URL rule.
    KEY_ALLOW      = "Allow".freeze
    # Key representing a disallow URL rule.
    KEY_DISALLOW   = "Disallow".freeze

    # Value representing the Wgit user agent.
    USER_AGENT_WGIT = :wgit.freeze
    # Value representing any user agent including Wgit.
    USER_AGENT_ANY  = :*.freeze

    # Hash containing the user-agent allow/disallow URL rules. Looks like:
    #   allow_paths:    ["/"]
    #   disallow_paths: ["/accounts", ...]
    attr_reader :rules

    # Initializes and returns a Wgit::Robots::Parser instance having parsed the
    # robot.txt contents.
    #
    # @param contents [String, #to_s] The contents of the robots.txt file to be
    #   parsed.
    def initialize(contents)
      @rules = {
        allow_paths: Set.new,
        disallow_paths: Set.new,
      }

      assert_respond_to(contents, :to_s)
      parse(contents.to_s)
    end

    # Overrides String#inspect to shorten the printed output of a Parser.
    #
    # @return [String] A short textual representation of this Parser.
    def inspect
      "#<Wgit::Robots::Parser rules=#{rules?} no_index=#{no_index?}>"
    end

    # Returns whether or not there are rules applying to Wgit.
    #
    # @return [Boolean] True if there are fules for Wgit to follow, false
    #   otherwise.
    def rules?
      @rules[:allow_paths].any? || @rules[:disallow_paths].any?
    end

    # Returns whether or not Wgit is banned from indexing this site.
    #
    # @return [Boolean] True if Wgit should not index this site, false
    #   otherwise.
    def no_index?
      @rules[:disallow_paths].any? { |path| ['*', '/'].include?(path) }
    end

    private

    # Parses the file contents and sets @rules.
    def parse(contents)
      user_agent = USER_AGENT_ANY

      contents.split("\n").each do |line|
        line.strip!
        next if line == ""

        if line.start_with?(KEY_USER_AGENT)
          user_agent = remove_key(line, KEY_USER_AGENT).downcase.to_sym
        elsif line.start_with?(KEY_ALLOW)
          append_allow_rule(user_agent, line)
        elsif line.start_with?(KEY_DISALLOW)
          append_disallow_rule(user_agent, line)
        else
          Wgit.logger.debug("Skipping unsupported robots.txt line: #{line}")
        end
      end
    end

    # Returns line with key removed (if present). Otherwise line is returned as given.
    def remove_key(line, key)
      prefix = "#{key}:"
      segs = line.split(prefix)
      value = segs.size <= 1 ? line : segs[1]
      value.strip
    end

    def append_allow_rule(user_agent, line)
      return unless wgit_user_agent?(user_agent)

      path = remove_key(line, KEY_ALLOW)
      @rules[:allow_paths] << path
    end

    def append_disallow_rule(user_agent, line)
      return unless wgit_user_agent?(user_agent)

      path = remove_key(line, KEY_DISALLOW)
      @rules[:disallow_paths] << path
    end

    def wgit_user_agent?(user_agent)
      [USER_AGENT_ANY, USER_AGENT_WGIT].include?(user_agent)
    end

    alias banned? no_index?
  end
end
