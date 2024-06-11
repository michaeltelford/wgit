# frozen_string_literal: true

### Default Document Extractors ###

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
  if keywords && type == :document
    keywords = keywords.split(',')
    keywords = Wgit::Utils.sanitize(keywords)
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
  '/html', # TODO: Pass nil here to skip the xpath computation
  singleton: false,
  text_content_only: true
) do |text, doc, type|
  if type == :document
    html_to_text = Wgit::HtmlToText.new(doc.parser)
    text = html_to_text.extract
  end

  text
end
