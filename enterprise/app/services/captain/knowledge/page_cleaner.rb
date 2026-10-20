# Site-independent cleaning of crawled page markdown (knowledge processing version 3).
# Keeps prose, lists, tables and code; drops what only makes sense on screen: navigation
# and link lists, buttons, logos and decorative images, orphan labels, blocks repeated
# across the site (learned during discovery) and repeated copies within the page.
class Captain::Knowledge::PageCleaner
  IMAGE = /!\[([^\]]*)\]\([^)]*\)/
  LINK = /\[([^\]]*)\]\([^)]*\)/
  EMPHASIS = /(\*\*|__)(?=\S)(.+?)(?<=\S)\1/
  WORD = /[\p{L}\p{N}]+/
  DECORATIVE_ALT = /logo|icon|image|img|banner|avatar|screenshot|thumbnail|placeholder|\.(?:svg|png|jpe?g|gif|webp)\z/i
  # Blocks this short without sentence punctuation or numbers are labels: buttons, tabs, badges.
  LABEL_WORDS = 3
  LINK_LIST_RATIO = 0.8
  LINK_LIST_WORDS = 12
  LIST_ITEM = /\A\s*(?:[-*+]|\d+[.)])\s/
  TABLE_ROW = /\A\s*\|/
  FENCE = /\A\s*(```|~~~)/
  INVISIBLE = /[\u200B-\u200D\u2060\uFEFF\u00AD]/
  COPYRIGHT = /\A\W*(?:copyright|©|\(c\))|all rights reserved/i

  def self.block_hash(text) = Digest::SHA256.hexdigest(normalize(unwrap(text))).first(12)
  def self.normalize(text) = text.downcase.gsub(/\s+/, ' ').strip
  def self.unwrap(text) = text.gsub(IMAGE, '').gsub(LINK, '\1').gsub(EMPHASIS, '\2')

  # Hashes of the non-heading blocks of a page, for learning site-wide boilerplate.
  def self.block_hashes(markdown)
    blocks(markdown).reject { |block| heading?(block) || block.match?(FENCE) }.map { |block| block_hash(block) }.uniq
  end

  # Card links wrap whole blocks ("[" … "](url)" on their own lines); drop the wrapper, keep the card text.
  def self.blocks(markdown)
    text = markdown.to_s.gsub(INVISIBLE, '').gsub(/^[ \t]*\[[ \t]*$/, '').gsub(/^[ \t]*\]\([^)\n]*\)[ \t]*$/, '')
    paragraphs = text.split(/\n[ \t]*\n/).each_with_object([]) do |part, result|
      # A fenced code block can contain blank lines; keep it whole.
      if result.last && result.last.lines.count { |line| line.match?(FENCE) }.odd?
        result[-1] = "#{result.last}\n\n#{part}"
      else
        result << part.strip
      end
    end
    paragraphs.flat_map { |block| split_headings(block) }.reject(&:empty?)
  end

  # A heading line directly followed by text ("## Effects" then "[edit]") is still its own block.
  def self.split_headings(block)
    return [block] if block.match?(FENCE)

    groups = block.lines.map(&:chomp).slice_when { |line, following| [line, following].any? { |item| heading?(item) } }
    groups.map { |lines| lines.join("\n").strip }
  end

  def self.heading?(block) = block.match?(Captain::Knowledge::SectionedText::HEADING)

  def initialize(markdown, boilerplate: [])
    @markdown = markdown.to_s
    @boilerplate = boilerplate.to_set
  end

  def perform
    blocks = self.class.blocks(@markdown)
    @occurrences = blocks.map { |block| self.class.normalize(self.class.unwrap(block)) }.tally
    seen = Set.new
    kept = blocks.each_with_index.filter_map do |block, index|
      next clean_heading(block) if self.class.heading?(block)
      next block if block.match?(FENCE)

      text = clean_block(block)
      text if keep?(block, text, blocks[index + 1]) && seen.add?(self.class.normalize(text))
    end
    drop_empty_sections(kept).join("\n\n")
  end

  private

  def clean_heading(block)
    block.gsub(IMAGE, '').gsub(LINK, '\1').gsub(EMPHASIS, '\2').delete('`').squeeze(' ').strip
  end

  def clean_block(block)
    block.gsub(IMAGE) { descriptive_alt(Regexp.last_match(1)) }.gsub(LINK, '\1').gsub(EMPHASIS, '\2')
         .lines.map(&:rstrip).reject { |line| line.strip.match?(/\A[-*+]?\s*\z/) }.join("\n").strip
  end

  def descriptive_alt(alt)
    alt = alt.to_s.strip
    alt.scan(WORD).size >= 3 && !alt.match?(DECORATIVE_ALT) ? alt : ''
  end

  def keep?(original, text, following)
    words = text.gsub(%r{https?://\S+}, '').scan(WORD).size
    return true if words.positive? && text.match?(TABLE_ROW)
    return false if chrome?(original, text, words)

    label = label?(text, words)
    # A short title introducing its description stays even when the same words also appear in the site menu.
    return inline_title?(original, following) if label

    @boilerplate.exclude?(self.class.block_hash(original))
  end

  # Empty blocks, link lists and copyright lines are page furniture, never knowledge.
  def chrome?(original, text, words)
    words.zero? || link_list?(original, words) || (text.match?(COPYRIGHT) && words <= 20)
  end

  # A card or feature title: a one-off short line, not a link, followed by its description.
  # Buttons repeat ("See a demo" under every card) or are links.
  def inline_title?(original, following)
    return false if following.nil? || self.class.heading?(following) || original.match?(LINK)
    return false unless @occurrences[self.class.normalize(self.class.unwrap(original))] == 1

    words = self.class.unwrap(following).scan(WORD).size
    words >= 8 && !link_list?(following, words)
  end

  # Menus, "related articles" lists and call-to-action buttons: almost every word is a link.
  def link_list?(original, words)
    link_words = original.gsub(IMAGE, '').scan(LINK).sum { |(label)| label.scan(WORD).size }
    link_words.fdiv(words) >= LINK_LIST_RATIO && (words <= LINK_LIST_WORDS || original.lines.all? { |line| line.match?(LIST_ITEM) })
  end

  def label?(text, words)
    words <= LABEL_WORDS && !text.match?(/[.!?:;]|\d/) && !text.match?(LIST_ITEM)
  end

  # A heading followed only by deeper headings or nothing introduces no content.
  def drop_empty_sections(blocks)
    blocks.each_with_index.reject do |block, index|
      next false unless self.class.heading?(block)

      level = block[/\A\s*(#+)/, 1].length
      following = blocks[(index + 1)..].find { |next_block| !self.class.heading?(next_block) || heading_level(next_block) <= level }
      following.nil? || self.class.heading?(following)
    end.map(&:first)
  end

  def heading_level(block) = block[/\A\s*(#+)/, 1].length
end
