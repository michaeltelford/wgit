### Default Document Extensions ###

# Title.
Wgit::Document.define_extension(
  :title,
  '//title',
  singleton: true,
  text_content_only: true,
)

# Author.
Wgit::Document.define_extension(
  :author,
  '//meta[@name="author"]/@content',
  singleton: true,
  text_content_only: true,
)

# Keywords.
Wgit::Document.define_extension(
  :keywords,
  '//meta[@name="keywords"]/@content',
  singleton: true,
  text_content_only: true,
) do |keywords, source|
  if keywords and source == :html
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
  text_content_only: true,
) do |links|
  if links
    links.map! do |link|
      Wgit::Url.new(link)
    rescue
      nil
    end
    links.compact!
  end
  links
end

# Text.
Wgit::Document.define_extension(
  :text,
  proc { Wgit::Document.text_elements_xpath },
  singleton: false,
  text_content_only: true,
)
