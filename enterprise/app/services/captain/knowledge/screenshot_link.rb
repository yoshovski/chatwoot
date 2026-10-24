# Keep instructional screenshots as explicit links, not arbitrary HTML or model-generated images.
module Captain::Knowledge::ScreenshotLink
  LINE = %r{\[Screenshot: ([^\]\n]+)\]\((https://[^\s)]+)\)}
  DECORATIVE = /\b(?:logo|icon|avatar|banner|placeholder|thumbnail)\b/i

  def self.normalize(markdown, page_url:)
    links = Captain::Knowledge::PageLinks.new(page_url)
    # ReadMe's markdown endpoint returns MDX Image components, not Markdown images.
    text = markdown.gsub(%r{<Image\b[^>]*/?\s*>}im) do |tag|
      attrs = tag.scan(/\b(src|caption|alt)=["']([^"']*)["']/).to_h
      link(attrs['caption'].presence || attrs['alt'], attrs['src'], links)
    end
    text.gsub(/!\[([^\]]*)\]\(([^)]+)\)/) { link(Regexp.last_match(1), Regexp.last_match(2), links) }
  end

  def self.link(caption, target, links)
    caption = caption.to_s.squish
    return '' if caption.scan(/[[:alnum:]]+/).size < 3 || caption.match?(DECORATIVE)

    url = links.resolve(target)
    return '' unless url&.start_with?('https://')

    "[Screenshot: #{caption.tr('[]', '()')}](#{url})"
  end

  def self.line?(block)
    block.strip.match?(/\A#{LINE}\z/o)
  end
end
