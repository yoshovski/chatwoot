# Turns a supported video embed into the public URL customers can open on any channel. The chat widget
# recognises the same URLs and plays them in place. Other embeds are dropped with the rest of the iframes.
module Captain::Knowledge::VideoLink
  PATTERNS = {
    %r{\Ahttps://(?:www\.)?youtube(?:-nocookie)?\.com/embed/([\w-]{6,})} => 'https://www.youtube.com/watch?v=%s',
    %r{\Ahttps://youtu\.be/([\w-]{6,})} => 'https://www.youtube.com/watch?v=%s',
    %r{\Ahttps://player\.vimeo\.com/video/(\d+)} => 'https://vimeo.com/%s',
    %r{\Ahttps://fast\.wistia\.(?:net|com)/embed/(?:iframe|medias)/(\w+)} => 'https://fast.wistia.net/embed/iframe/%s',
    %r{\Ahttps://(?:www\.)?loom\.com/embed/(\w+)} => 'https://www.loom.com/share/%s'
  }.freeze
  # The URLs from_embed returns, matched again when cleaning the page text.
  WATCH_URL = %r{\Ahttps://(?:www\.youtube\.com/watch\?v=|vimeo\.com/\d|fast\.wistia\.net/embed/iframe/|www\.loom\.com/share/)}
  VIDEO_FILE = %r{\Ahttps://[^\s?#]+\.(?:mp4|webm)(?:[?#]\S*)?\z}i
  # Player names such as "Wistia video player" say nothing about the content.
  GENERIC_TITLE = /video player|\A(?:youtube|vimeo|wistia|loom)\b/i

  def self.from_embed(src)
    src = src.to_s.strip
    src = "https:#{src}" if src.start_with?('//')
    return src if src.match?(VIDEO_FILE)

    PATTERNS.each { |pattern, url| return format(url, Regexp.last_match(1)) if src.match(pattern) }
    nil
  end

  # A "[Video…](url)" or "[Watch: …](url)" line from the page reader.
  def self.line?(block)
    match = block.strip.match(/\A\[((?:Video|Watch:)[^\]]*)\]\((\S+)\)\z/)
    match.present? && (match[2].match?(WATCH_URL) || match[2].match?(VIDEO_FILE))
  end

  # Without a useful player title the video is named after the page it is on ("Watch: <page title>"), else "Video".
  def self.label(title, page_title: nil)
    title = title.to_s.squish
    return "Video: #{title.truncate(80)}" unless title.blank? || title.match?(GENERIC_TITLE)

    page_title = page_title.to_s.squish
    page_title.present? ? "Watch: #{page_title.truncate(60)}" : 'Video'
  end
end
