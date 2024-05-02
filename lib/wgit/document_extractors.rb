# frozen_string_literal: true

### Default Document Extractors ###

# Base string.
Wgit::Document.define_extractor(
  :base,
  '//base/@href',
  singleton: true,
  text_content_only: true
) do |base|
  Wgit::Url.parse?(base) if base
end

# Title string.
Wgit::Document.define_extractor(
  :title,
  '//title',
  singleton: true,
  text_content_only: true
)

# Description string.
Wgit::Document.define_extractor(
  :description,
  '//meta[@name="description"]/@content',
  singleton: true,
  text_content_only: true
)

# Author string.
Wgit::Document.define_extractor(
  :author,
  '//meta[@name="author"]/@content',
  singleton: true,
  text_content_only: true
)

# Keywords array.
Wgit::Document.define_extractor(
  :keywords,
  '//meta[@name="keywords"]/@content',
  singleton: true,
  text_content_only: true
) do |keywords, _source, type|
  if keywords && (type == :document)
    keywords = keywords.split(',')
    keywords = Wgit::Utils.sanitize(keywords)
  end

  keywords
end

# Links array.
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

# Text array.
Wgit::Document.define_extractor(
  :text,
  '/html',
  singleton: true,
  text_content_only: false
) do |el_or_text, doc, type|
  text = el_or_text
  if el_or_text && (type == :document)
    html = el_or_text.to_s
    text = doc.send(:extract_text, html)
  end

  text || []
end
