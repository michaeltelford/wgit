require_relative "helpers/test_helper"

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
      allow_paths:    Set.new(["/michaeltelford/wgit/wiki/*"]),
      disallow_paths: Set.new([
        "/buzz/*.xml",
        "/category/*.xml",
        "/mobile/",
        "*?s=bpage-next",
        "*?s=lightbox",
        "*?s=feedpager",
        "/fabordrab/",
        "/bfmp/",
        "/buzzfeed/",
        "/michaeltelford/wgit/wiki/*/_history",
        "*"
      ])
    }, p.rules)
    assert_equal ["/michaeltelford/wgit/wiki/*"], p.allow_paths
    assert_equal([
      "/buzz/*.xml",
      "/category/*.xml",
      "/mobile/",
      "*?s=bpage-next",
      "*?s=lightbox",
      "*?s=feedpager",
      "/fabordrab/",
      "/bfmp/",
      "/buzzfeed/",
      "/michaeltelford/wgit/wiki/*/_history",
      "*"
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
      disallow_paths: Set.new(["/"])
    }, p.rules)
    assert_empty p.allow_paths
    assert_equal ["/"], p.disallow_paths
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
      disallow_paths: Set.new(["*"])
    }, p.rules)
    assert_empty p.allow_paths
    assert_equal ["*"], p.disallow_paths
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
      allow_paths:    Set.new(["/about"]),
      disallow_paths: Set.new(["/*.xml"])
    }, p.rules)
    assert_equal ["/about"], p.allow_paths
    assert_equal ["/*.xml"], p.disallow_paths
  end

  def test_initialize__no_white_space
    p = Wgit::RobotsParser.new robots_txt__no_white_space

    assert p.rules?
    assert p.allow_rules?
    assert p.disallow_rules?
    refute p.no_index?
    assert_equal({
      allow_paths:    Set.new(["/about"]),
      disallow_paths: Set.new(["/*.xml"])
    }, p.rules)
    assert_equal ["/about"], p.allow_paths
    assert_equal ["/*.xml"], p.disallow_paths
  end

  def test_initialize__case_insensitive
    p = Wgit::RobotsParser.new <<~TEXT
      User-agENt: wGIt
      CrAwl-deLay: 120
      AlLOw: /about
      DisaLLow: /*.xml
    TEXT

    assert p.rules?
    assert p.allow_rules?
    assert p.disallow_rules?
    refute p.no_index?
    assert_equal({
      allow_paths:    Set.new(["/about"]),
      disallow_paths: Set.new(["/*.xml"])
    }, p.rules)
    assert_equal ["/about"], p.allow_paths
    assert_equal ["/*.xml"], p.disallow_paths
  end

  def test_initialize__cloudflare
    p = Wgit::RobotsParser.new robots_txt__cloudflare

    assert p.rules?
    refute p.allow_rules?
    assert p.disallow_rules?
    refute p.no_index?
    assert_equal({
      allow_paths:    Set.new,
      disallow_paths: Set.new(expected_disallow_paths__cloudflare)
    }, p.rules)
    assert_empty p.allow_paths
    assert_equal expected_disallow_paths__cloudflare, p.disallow_paths
  end

  def test_initialize__dollar_sign
    p = Wgit::RobotsParser.new <<~TEXT
      User-agent: *
      Allow: /about$
    TEXT

    assert p.rules?
    assert p.allow_rules?
    refute p.disallow_rules?
    refute p.no_index?
    assert_equal({
      allow_paths:    Set.new(["/about"]),
      disallow_paths: Set.new
    }, p.rules)
    assert_equal ["/about"], p.allow_paths
    assert_empty p.disallow_paths
  end

  def test_initialize__inline_comment
    p = Wgit::RobotsParser.new <<~TEXT
      User-agent: *
      Allow: /about # Allow about page to all.
      Disallow: /contact#support
    TEXT

    assert p.rules?
    assert p.allow_rules?
    assert p.disallow_rules?
    refute p.no_index?
    assert_equal({
      allow_paths:    Set.new(["/about"]),
      disallow_paths: Set.new(["/contact#support"])
    }, p.rules)
    assert_equal ["/about"], p.allow_paths
    assert_equal ["/contact#support"], p.disallow_paths
  end

  def test_initialize__blank_path__allow
    p = Wgit::RobotsParser.new <<~TEXT
      User-agent: wgit
      Allow:
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

  def test_initialize__blank_path__disallow
    p = Wgit::RobotsParser.new <<~TEXT
      User-agent: *
      Disallow:
    TEXT

    assert p.rules?
    refute p.allow_rules?
    assert p.disallow_rules?
    assert p.no_index?
    assert_equal({
      allow_paths:    Set.new,
      disallow_paths: Set.new(["*"])
    }, p.rules)
    assert_empty p.allow_paths
    assert_equal ["*"], p.disallow_paths
  end

  private

  def robots_txt__default
    <<~TEXT
      User-agent: msnbot
      Crawl-delay: 120
      Disallow: /*.xml$
      Disallow: /buzz/*.xml$

      # All user agents
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

  def robots_txt__no_white_space
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

  def robots_txt__cloudflare
    <<~TEXT
      #    .__________________________.
      #    | .___________________. |==|
      #    | | ................. | |  |
      #    | | ::[ Dear robot ]: | |  |
      #    | | ::::[ be nice ]:: | |  |
      #    | | ::::::::::::::::: | |  |
      #    | | ::::::::::::::::: | |  |
      #    | | ::::::::::::::::: | |  |
      #    | | ::::::::::::::::: | | ,|
      #    | !___________________! |(c|
      #    !_______________________!__!
      #   /                            \
      #  /  [][][][][][][][][][][][][]  \
      # /  [][][][][][][][][][][][][][]  \
      #(  [][][][][____________][][][][]  )
      # \ ------------------------------ /
      #  \______________________________/


      #       _-_
      #    /~~   ~~\
      # /~~         ~~\

      # \  _-     -_  /
      #   ~  \\ //  ~
      #_- -   | | _- _
      #  _ -  | |   -_
      #      // \\
      # OUR TREE IS A REDWOOD


      # allow TwitterBot to crawl lp
      User-agent: Twitterbot

      Allow: /lp
      Allow: /de-de/lp
      Allow: /en-au/lp
      Allow: /en-ca/lp
      Allow: /en-gb/lp
      Allow: /en-in/lp
      Allow: /es-es/lp
      Allow: /es-la/lp
      Allow: /fr-fr/lp
      Allow: /it-it/lp
      Allow: /ja-jp/lp
      Allow: /ko-kr/lp
      Allow: /pt-br/lp
      Allow: /zh-cn/lp
      Allow: /zh-tw/lp

      User-agent: *

      # pages testing
      Disallow: pages.www.cloudflare.com/
      Disallow: en-us.www.cloudflare.com/

      # lp
      Disallow: /lp
      Disallow: /de-de/lp
      Disallow: /en-au/lp
      Disallow: /en-ca/lp
      Disallow: /en-gb/lp
      Disallow: /en-in/lp
      Disallow: /es-es/lp
      Disallow: /es-la/lp
      Disallow: /fr-fr/lp
      Disallow: /it-it/lp
      Disallow: /ja-jp/lp
      Disallow: /ko-kr/lp
      Disallow: /pt-br/lp
      Disallow: /zh-cn/lp
      Disallow: /zh-tw/lp

      # feedback
      Disallow: /feedback
      Disallow: /de-de/feedback
      Disallow: /en-au/feedback
      Disallow: /en-ca/feedback
      Disallow: /en-gb/feedback
      Disallow: /en-in/feedback
      Disallow: /es-es/feedback
      Disallow: /es-la/feedback
      Disallow: /fr-fr/feedback
      Disallow: /it-it/feedback
      Disallow: /ja-jp/feedback
      Disallow: /ko-kr/feedback
      Disallow: /pt-br/feedback
      Disallow: /zh-cn/feedback
      Disallow: /zh-tw/feedback

      Sitemap: https://www.cloudflare.com/sitemap.xml
      Sitemap: https://www.cloudflare.com/de-de/sitemap.xml
      Sitemap: https://www.cloudflare.com/en-au/sitemap.xml
      Sitemap: https://www.cloudflare.com/en-ca/sitemap.xml
      Sitemap: https://www.cloudflare.com/en-gb/sitemap.xml
      Sitemap: https://www.cloudflare.com/en-in/sitemap.xml
      Sitemap: https://www.cloudflare.com/es-es/sitemap.xml
      Sitemap: https://www.cloudflare.com/es-la/sitemap.xml
      Sitemap: https://www.cloudflare.com/fr-fr/sitemap.xml
      Sitemap: https://www.cloudflare.com/it-it/sitemap.xml
      Sitemap: https://www.cloudflare.com/ja-jp/sitemap.xml
      Sitemap: https://www.cloudflare.com/ko-kr/sitemap.xml
      Sitemap: https://www.cloudflare.com/pt-br/sitemap.xml
      Sitemap: https://www.cloudflare.com/zh-cn/sitemap.xml
      Sitemap: https://www.cloudflare.com/zh-tw/sitemap.xml



      #              ________
      #   __,_,     |        |
      #  [_|_/      |   OK   |
      #   //        |________|
      # _//    __  /
      #(_|)   |@@|
      # \ \__ \--/ __
      #  \o__|----|  |   __
      #      \ }{ /\ )_ / _\
      #      /\__/\ \__O (__
      #     (--/\--)    \__/
      #     _)(  )(_
      #    `---''---`
    TEXT
  end

  def expected_disallow_paths__cloudflare
    [
      "pages.www.cloudflare.com/",
      "en-us.www.cloudflare.com/",
      "/lp",
      "/de-de/lp",
      "/en-au/lp",
      "/en-ca/lp",
      "/en-gb/lp",
      "/en-in/lp",
      "/es-es/lp",
      "/es-la/lp",
      "/fr-fr/lp",
      "/it-it/lp",
      "/ja-jp/lp",
      "/ko-kr/lp",
      "/pt-br/lp",
      "/zh-cn/lp",
      "/zh-tw/lp",
      "/feedback",
      "/de-de/feedback",
      "/en-au/feedback",
      "/en-ca/feedback",
      "/en-gb/feedback",
      "/en-in/feedback",
      "/es-es/feedback",
      "/es-la/feedback",
      "/fr-fr/feedback",
      "/it-it/feedback",
      "/ja-jp/feedback",
      "/ko-kr/feedback",
      "/pt-br/feedback",
      "/zh-cn/feedback",
      "/zh-tw/feedback"
    ]
  end
end
