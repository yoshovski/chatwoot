class Captain::Knowledge::SectionedText
  HEADING = /\A {0,3}(\#{1,6})[ \t]+(.+?)(?:[ \t]+\#+)?[ \t]*\z/
  FENCE = /\A\s*(```|~~~)/
  SEPARATOR = ' > '.freeze
  SECTION_SEPARATOR = "\n\n<!-- captain:section -->\n\n".freeze
  THEMATIC_BREAK = /\A {0,3}(?:(?:\*\s*){3,}|(?:-\s*){3,}|(?:_\s*){3,})\z/
  MAX_BREADCRUMB_LENGTH = 200
  # Crawled pages often have section titles as plain lines; they sit below every `#` level.
  SECTION_TITLE_LEVEL = 7
  SECTION_TITLE_MAX_LENGTH = 80
  SECTION_TITLE_PUNCTUATION = /[.:?!]/
  LIST_OR_QUOTE = /\A[-*+>|]/

  def initialize(markdown, title:, infer_plain_titles: true)
    @markdown = markdown.to_s
    @title = title.to_s.strip
    @infer_plain_titles = infer_plain_titles
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

    @blocks.map { |path, text| [path.presence, text].compact.join("\n") }.join(SECTION_SEPARATOR)
  end

  private

  def read_line(line)
    return if separator_line?(line)

    @in_fence = !@in_fence if line.match?(FENCE)
    heading = heading_for(line)
    if heading
      flush_body
      release_pending_title
      add_heading(heading[1].length, heading[2])
    elsif line.strip.empty? && !@in_fence
      flush_body
    else
      @body << line.rstrip
    end
  end

  def numeric_heading?(heading)
    heading && !@infer_plain_titles && heading[2].match?(/\A[\d\s.,%+]+[KMBkmb]?\z/)
  end

  def heading_for(line)
    return if @in_fence

    heading = line.match(HEADING)
    heading unless numeric_heading?(heading)
  end

  def separator_line?(line)
    !@in_fence && line.match?(THEMATIC_BREAK)
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
    path = breadcrumb
    text = lines.join("\n")
    if @blocks.last&.first == path
      @blocks.last[1] += "\n\n#{text}"
    else
      @blocks << [path, text]
    end
  end

  def section_title?(lines)
    return false unless @infer_plain_titles

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
