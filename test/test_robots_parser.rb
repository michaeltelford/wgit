require_relative 'helpers/test_helper'

# Test class for the RobotsParser methods.
class TestRobotsParser < TestHelper
  # Run non DB tests in parallel for speed.
  parallelize_me!

  # Runs before every test.
  def setup; end

  def test_initialize
    p = Wgit::RobotsParser.new robots_txt__default

    assert p.rules?
    assert p.allow_rules?
    assert p.disallow_rules?
    assert p.no_index?
    assert_equal({
      allow_paths:    Set.new(['/michaeltelford/wgit/wiki/*']),
      disallow_paths: Set.new([
        '/buzz/*.xml$',
        '/category/*.xml$',
        '/mobile/',
        '*?s=bpage-next',
        '*?s=lightbox',
        '*?s=feedpager',
        '/fabordrab/',
        '/bfmp/',
        '/buzzfeed/',
        '/michaeltelford/wgit/wiki/*/_history',
        '*'
      ])
    }, p.rules)
    assert_equal ['/michaeltelford/wgit/wiki/*'], p.allow_paths
    assert_equal([
      '/buzz/*.xml$',
      '/category/*.xml$',
      '/mobile/',
      '*?s=bpage-next',
      '*?s=lightbox',
      '*?s=feedpager',
      '/fabordrab/',
      '/bfmp/',
      '/buzzfeed/',
      '/michaeltelford/wgit/wiki/*/_history',
      '*'
    ], p.disallow_paths)
  end

  def test_initialize__disallow_slash
    p = Wgit::RobotsParser.new <<~TEXT
      User-agent: wgit
      Disallow: /
    TEXT

    assert p.rules?
    refute p.allow_rules?
    assert p.disallow_rules?
    assert p.no_index?
    assert_equal({
      allow_paths:    Set.new,
      disallow_paths: Set.new(['/'])
    }, p.rules)
    assert_empty p.allow_paths
    assert_equal ['/'], p.disallow_paths
  end

  def test_initialize__disallow_asterisk
    p = Wgit::RobotsParser.new <<~TEXT
      User-agent: wgit
      Disallow: *
    TEXT

    assert p.rules?
    refute p.allow_rules?
    assert p.disallow_rules?
    assert p.no_index?
    assert_equal({
      allow_paths:    Set.new,
      disallow_paths: Set.new(['*'])
    }, p.rules)
    assert_empty p.allow_paths
    assert_equal ['*'], p.disallow_paths
  end

  def test_initialize__allow_slash
    p = Wgit::RobotsParser.new <<~TEXT
      User-agent: wgit
      Allow: /
    TEXT

    refute p.rules?
    refute p.allow_rules?
    refute p.disallow_rules?
    refute p.no_index?
    assert_equal({
      allow_paths:    Set.new,
      disallow_paths: Set.new
    }, p.rules)
    assert_empty p.allow_paths
    assert_empty p.disallow_paths
  end

  def test_initialize__allow_asterisk
    p = Wgit::RobotsParser.new <<~TEXT
      User-agent: wgit
      Allow: *
    TEXT

    refute p.rules?
    refute p.allow_rules?
    refute p.disallow_rules?
    refute p.no_index?
    assert_equal({
      allow_paths:    Set.new,
      disallow_paths: Set.new
    }, p.rules)
    assert_empty p.allow_paths
    assert_empty p.disallow_paths
  end

  def test_initialize__no_rules
    p = Wgit::RobotsParser.new <<~TEXT
      User-agent: slurp
      Disallow: *
    TEXT

    refute p.rules?
    refute p.allow_rules?
    refute p.disallow_rules?
    refute p.no_index?
    assert_equal({
      allow_paths:    Set.new,
      disallow_paths: Set.new
    }, p.rules)
    assert_empty p.allow_paths
    assert_empty p.disallow_paths
  end

  def test_initialize__user_agent_grouping
    p = Wgit::RobotsParser.new robots_txt__user_agent_grouping

    assert p.rules?
    assert p.allow_rules?
    assert p.disallow_rules?
    refute p.no_index?
    assert_equal({
      allow_paths:    Set.new(['/about']),
      disallow_paths: Set.new(['/*.xml'])
    }, p.rules)
    assert_equal ['/about'], p.allow_paths
    assert_equal ['/*.xml'], p.disallow_paths
  end

  private

  def robots_txt__default
    <<~TEXT
      User-agent: msnbot
      Crawl-delay: 120
      Disallow: /*.xml$
      Disallow: /buzz/*.xml$

      User-agent: *
      Disallow: /buzz/*.xml$
      Disallow: /category/*.xml$
      Disallow: /mobile/
      Disallow: *?s=bpage-next
      Disallow: *?s=lightbox
      Disallow: *?s=feedpager
      Disallow: /fabordrab/
      Disallow: /bfmp/
      Disallow: /buzzfeed/

      User-agent: discobot
      Disallow: /

      User-agent: dotbot
      Disallow: /

      User-agent: Slurp
      Crawl-delay: 4

      Sitemap: https://www.buzzfeed.com/sitemap/asis.xml
      Sitemap: https://www.buzzfeed.com/sitemap/buzzfeed.xml
      Sitemap: https://www.buzzfeed.com/sitemap/tasty.xml

      User-agent: yacybot
      Disallow: /

      User-agent: wgit
      Allow: /michaeltelford/wgit/wiki/*
      Disallow: /michaeltelford/wgit/wiki/*/_history

      User-agent: wgit
      Disallow: *
    TEXT
  end

  def robots_txt__user_agent_grouping
    <<~TEXT
      User-agent: blah
      Disallow: /

      User-agent: msnbot
      User-agent: wgit
      User-agent: googlebot
      Crawl-delay: 120
      Allow: /about
      Disallow: /*.xml

      User-agent: blah2
      Crawl-delay: 2
    TEXT
  end
end
