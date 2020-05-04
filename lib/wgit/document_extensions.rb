# frozen_string_literal: true

### Default Document Extensions ###

# Base.
Wgit::Document.define_extension(
  :base,
  '//base/@href',
  singleton: true,
  text_content_only: true
) do |base|
  Wgit::Url.parse?(base) if base
end

# Title.
Wgit::Document.define_extension(
  :title,
  '//title',
  singleton: true,
  text_content_only: true
)

# Description.
Wgit::Document.define_extension(
  :description,
  '//meta[@name="description"]/@content',
  singleton: true,
  text_content_only: true
)

# Author.
Wgit::Document.define_extension(
  :author,
  '//meta[@name="author"]/@content',
  singleton: true,
  text_content_only: true
)

# Keywords.
Wgit::Document.define_extension(
  :keywords,
  '//meta[@name="keywords"]/@content',
  singleton: true,
  text_content_only: true
) do |keywords, _source, type|
  if keywords && (type == :document)
    keywords = keywords.split(',')
    Wgit::Utils.process_arr(keywords)
  end
  keywords
end

# Links.
Wgit::Document.define_extension(
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
Wgit::Document.define_extension(
  :text,
  proc { Wgit::Document.text_elements_xpath },
  singleton: false,
  text_content_only: true
)
