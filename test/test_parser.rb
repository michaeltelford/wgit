require_relative 'helpers/test_helper'

# Test class for the Robots::Parser methods.
class TestParser < TestHelper
  # Run non DB tests in parallel for speed.
  parallelize_me!

  # Runs before every test.
  def setup; end

  def test_initialize
    p = Wgit::Robots::Parser.new robots_txt__default

    assert p.rules?
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
  end

  def test_initialize__disallow_slash
    p = Wgit::Robots::Parser.new <<~TEXT
      User-agent: wgit
      Disallow: /
    TEXT

    assert p.rules?
    assert p.no_index?
    assert_equal({
      allow_paths:    Set.new,
      disallow_paths: Set.new(['/'])
    }, p.rules)
  end

  def test_initialize__disallow_asterisk
    p = Wgit::Robots::Parser.new <<~TEXT
      User-agent: wgit
      Disallow: *
    TEXT

    assert p.rules?
    assert p.no_index?
    assert_equal({
      allow_paths:    Set.new,
      disallow_paths: Set.new(['*'])
    }, p.rules)
  end

  def test_initialize__allow_slash
    p = Wgit::Robots::Parser.new <<~TEXT
      User-agent: wgit
      Allow: /
    TEXT

    assert p.rules?
    refute p.no_index?
    assert_equal({
      allow_paths:    Set.new(['/']),
      disallow_paths: Set.new
    }, p.rules)
  end

  def test_initialize__allow_asterisk
    p = Wgit::Robots::Parser.new <<~TEXT
      User-agent: wgit
      Allow: *
    TEXT

    assert p.rules?
    refute p.no_index?
    assert_equal({
      allow_paths:    Set.new(['*']),
      disallow_paths: Set.new
    }, p.rules)
  end

  def test_initialize__no_rules
    p = Wgit::Robots::Parser.new <<~TEXT
      User-agent: slurp
      Disallow: *
    TEXT

    refute p.rules?
    refute p.no_index?
    assert_equal({
      allow_paths:    Set.new,
      disallow_paths: Set.new
    }, p.rules)
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
end
