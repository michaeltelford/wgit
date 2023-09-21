# frozen_string_literal: true

### Default Document Extractors ###

# No index.
Wgit::Document.define_extractor(
  :meta_robots,
  '//meta[@name="robots"]/@content',
  singleton: true,
  text_content_only: true
)
Wgit::Document.define_extractor(
  :meta_wgit,
  '//meta[@name="wgit"]/@content',
  singleton: true,
  text_content_only: true
)
class Wgit::Document
  def no_index?
    [@meta_robots, @meta_wgit].include?('noindex')
  end
end

# Base.
Wgit::Document.define_extractor(
  :base,
  '//base/@href',
  singleton: true,
  text_content_only: true
) do |base|
  Wgit::Url.parse?(base) if base
end

# Title.
Wgit::Document.define_extractor(
  :title,
  '//title',
  singleton: true,
  text_content_only: true
)

# Description.
Wgit::Document.define_extractor(
  :description,
  '//meta[@name="description"]/@content',
  singleton: true,
  text_content_only: true
)

# Author.
Wgit::Document.define_extractor(
  :author,
  '//meta[@name="author"]/@content',
  singleton: true,
  text_content_only: true
)

# Keywords.
Wgit::Document.define_extractor(
  :keywords,
  '//meta[@name="keywords"]/@content',
  singleton: true,
  text_content_only: true
) do |keywords, _source, type|
  if keywords && (type == :document)
    keywords = keywords.split(',')
    Wgit::Utils.sanitize(keywords)
  end
  keywords
end

# Links.
Wgit::Document.define_extractor(
  :links,
  '//a/@href',
  singleton: false,
  text_content_only: true
) do |links|
  links
    .map { |link| Wgit::Url.parse?(link) }
    .compact # Remove unparsable links.
end

# Text.
Wgit::Document.define_extractor(
  :text,
  proc { Wgit::Document.text_elements_xpath },
  singleton: false,
  text_content_only: true
)
