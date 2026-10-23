# Keeps the matched section first, then adds bounded excerpts in page order so a
# long how-to is not mistaken for just its key-creation or optional-settings step.
class Captain::Knowledge::DocumentExcerpt
  MATCHED_CHARS = 3500
  OUTLINE_CHARS = 1500
  SECTION_CHARS = 500

  def initialize(passage, limit:)
    @passage = passage
    @limit = limit
  end

  def perform
    matched = @passage.content.truncate(MATCHED_CHARS, separator: "\n")
    result = matched.present? ? "Matched section (excerpt):\n#{matched}\n\n" : ''
    sections = Captain::Knowledge::SectionedText.new(@passage.record.content, title: @passage.title, infer_plain_titles: false).sections
    outline = sections.flat_map { |path, _| path.drop(1) }.uniq.join("\n").truncate(OUTLINE_CHARS, separator: "\n")
    result += "Guide outline (headings only):\n#{outline}\n\nSection excerpts (not the complete procedure):\n"
    sections.each do |path, text|
      heading = path.drop(1).presence || path
      excerpt = "#{heading.join(' > ')}\n#{section_excerpt(text)}\n\n"
      break if result.length + excerpt.length > @limit

      result += excerpt
    end
    result
  end

  private

  def section_excerpt(text)
    blocks = Captain::Knowledge::PageCleaner.blocks(text).grep_v(/\A\s*(?:```|~~~|<Image\b)/)
    # Keep complete lines: cutting a markdown destination can turn a valid link into a broken one.
    lines = blocks.join("\n\n").lines
    size = 0
    lines.take_while { |line| (size += line.length) <= SECTION_CHARS }.join.strip
  end
end
