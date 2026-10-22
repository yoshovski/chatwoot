# Parent-child chunks for knowledge processing version 3.
#
# Parents are the context returned to the model: neighbouring sections are packed together
# up to PARENT_TARGET characters, starting a new parent at a new top-level topic once the
# current one has enough text. Children are what gets embedded: paragraphs packed up to
# CHILD_TARGET characters, each starting with a short context line (page title and nearest
# headings) so every child is searchable on its own. Parents are separated by
# SectionedText::SECTION_SEPARATOR and children by CHILD_SEPARATOR, which Dify splits on
# exactly without merging.
class Captain::Knowledge::ChunkPacker
  CHILD_SEPARATOR = "\n\n".freeze
  PARENT_TARGET = 3000
  PARENT_MIN = 800
  CHILD_TARGET = 800
  CHILD_MIN = 200
  CONTEXT_LENGTH = 120
  CONTEXT_SEPARATOR = ' > '.freeze

  def initialize(markdown, title:)
    @sections = Captain::Knowledge::SectionedText.new(markdown, title: title, infer_plain_titles: false).sections
  end

  def to_s
    parents = []
    @sections.each do |parts, text|
      parts = parts.map { |part| Captain::Knowledge::PageCleaner.unwrap(part).delete('`').strip }
      children(context(parts), text).each { |child| add(parents, child, parts[1]) }
    end
    parents.map { |parent| parent[:children].join(CHILD_SEPARATOR) }.join(Captain::Knowledge::SectionedText::SECTION_SEPARATOR)
  end

  private

  def add(parents, child, topic)
    parent = parents.last
    if parent.nil? || new_parent?(parent, child, topic)
      parents << { topic: topic, children: [child] }
    elsif merge_child?(parent[:children].last, child)
      parent[:children][-1] = "#{parent[:children].last}\n#{shorten_context(parent[:children].last, child)}"
    else
      parent[:children] << child
    end
  end

  def new_parent?(parent, child, topic)
    size = parent[:children].sum(&:length) + (CHILD_SEPARATOR.length * (parent[:children].size - 1))
    size + child.length > PARENT_TARGET || (parent[:topic] != topic && size >= PARENT_MIN)
  end

  # A one-line section would be a weak child alone; it joins its neighbour, keeping its own context line.
  def merge_child?(previous, child)
    (previous.length < CHILD_MIN || child.length < CHILD_MIN) && previous.length + child.length < CHILD_TARGET
  end

  # A merged child repeats only the part of its context line that differs from the child it joins.
  def shorten_context(previous, child)
    previous_parts = previous.lines.first.chomp.split(CONTEXT_SEPARATOR)
    context, body = child.split("\n", 2)
    parts = context.split(CONTEXT_SEPARATOR)
    shared = parts.zip(previous_parts).take_while { |part, other| part == other }.size
    return child if shared.zero?

    [parts.drop(shared).join(CONTEXT_SEPARATOR).presence, body].compact.join("\n")
  end

  # The page title, its top-level section and the two nearest headings: long guides repeat subheadings
  # ("Prerequisites", "Test your integration") under every section, so the section tells them apart.
  def context(parts)
    parts = [*parts.first(2), *parts.last(2)] if parts.size > 4
    parts.join(CONTEXT_SEPARATOR).truncate(CONTEXT_LENGTH).presence
  end

  def children(context, text)
    groups = pieces(text).slice_before(&new_group_tracker).to_a
    groups.map { |group| [context, *group].compact.join("\n") }
  end

  def new_group_tracker
    size = 0
    lambda do |piece|
      start = size.positive? && size + piece.length > CHILD_TARGET
      size = start ? piece.length : size + piece.length
      start
    end
  end

  # Paragraphs, with blank lines inside code blocks closed up; a paragraph longer than a child
  # is split at line, then sentence boundaries.
  def pieces(text)
    Captain::Knowledge::PageCleaner.blocks(text).flat_map do |paragraph|
      paragraph = paragraph.gsub(/\n[ \t]*\n/, "\n")
      next [paragraph] if paragraph.length <= CHILD_TARGET

      paragraph.split("\n").flat_map { |line| line.length > CHILD_TARGET ? line.split(/(?<=[.!?])\s+/) : [line] }
    end
  end
end
