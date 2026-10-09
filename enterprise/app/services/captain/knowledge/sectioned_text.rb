class Captain::Knowledge::SectionedText
  HEADING = /\A {0,3}(\#{1,6})[ \t]+(.+?)(?:[ \t]+\#+)?[ \t]*\z/
  FENCE = /\A\s*(```|~~~)/
  SEPARATOR = ' > '.freeze
  MAX_BREADCRUMB_LENGTH = 200
  # Crawled pages often have section titles as plain lines; they sit below every `#` level.
  SECTION_TITLE_LEVEL = 7
  SECTION_TITLE_MAX_LENGTH = 80
  SECTION_TITLE_PUNCTUATION = /[.:?!]/
  LIST_OR_QUOTE = /\A[-*+>|]/

  def initialize(markdown, title:)
    @markdown = markdown.to_s
    @title = title.to_s.strip
  end

  def to_s
    @headings = []
    @blocks = []
    @body = []
    @pending_title = nil
    @in_fence = false

    @markdown.each_line(chomp: true) { |line| read_line(line) }
    flush_body
    release_pending_title

    @blocks.join("\n\n")
  end

  private

  def read_line(line)
    @in_fence = !@in_fence if line.match?(FENCE)
    heading = line.match(HEADING) unless @in_fence
    if heading
      flush_body
      release_pending_title
      add_heading(heading[1].length, heading[2])
    elsif line.strip.empty?
      flush_body
    else
      @body << line.rstrip
    end
  end

  def add_heading(level, text)
    @headings.pop while @headings.any? && @headings.last.first >= level
    @headings << [level, text.strip]
  end

  # A one-line title is held back: it becomes a section only if body text follows it.
  def flush_body
    return if @body.empty?

    lines = @body
    @body = []
    if section_title?(lines)
      release_pending_title
      @pending_title = lines.first
    else
      adopt_pending_title
      emit(lines)
    end
  end

  def adopt_pending_title
    return unless @pending_title

    add_heading(SECTION_TITLE_LEVEL, @pending_title)
    @pending_title = nil
  end

  def release_pending_title
    return unless @pending_title

    emit([@pending_title])
    @pending_title = nil
  end

  def emit(lines)
    @blocks << [breadcrumb.presence, *lines].compact.join("\n")
  end

  def section_title?(lines)
    line = lines.first.strip
    lines.one? && line.length <= SECTION_TITLE_MAX_LENGTH && line.match?(/\p{L}/) &&
      !line.match?(SECTION_TITLE_PUNCTUATION) && !line.match?(LIST_OR_QUOTE)
  end

  def breadcrumb
    parts = [@title, *@headings.map(&:last)].compact_blank.chunk_while { |a, b| a.casecmp?(b) }.map(&:first)
    parts.shift while parts.size > 1 && parts.join(SEPARATOR).length > MAX_BREADCRUMB_LENGTH
    parts.join(SEPARATOR)
  end
end
