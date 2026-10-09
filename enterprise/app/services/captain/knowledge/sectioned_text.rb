class Captain::Knowledge::SectionedText
  HEADING = /\A {0,3}(\#{1,6})[ \t]+(.+?)(?:[ \t]+\#+)?[ \t]*\z/
  FENCE = /\A\s*(```|~~~)/
  SEPARATOR = ' > '.freeze
  MAX_BREADCRUMB_LENGTH = 200

  def initialize(markdown, title:)
    @markdown = markdown.to_s
    @title = title.to_s.strip
  end

  def to_s
    @headings = []
    @blocks = []
    @body = []
    in_fence = false

    @markdown.each_line(chomp: true) do |line|
      in_fence = !in_fence if line.match?(FENCE)
      heading = line.match(HEADING) unless in_fence
      if heading
        flush_body
        add_heading(heading[1].length, heading[2])
      elsif line.strip.empty?
        flush_body
      else
        @body << line.rstrip
      end
    end
    flush_body

    @blocks.join("\n\n")
  end

  private

  def add_heading(level, text)
    @headings.pop while @headings.any? && @headings.last.first >= level
    @headings << [level, text.strip]
  end

  def flush_body
    return if @body.empty?

    @blocks << [breadcrumb.presence, *@body].compact.join("\n")
    @body = []
  end

  def breadcrumb
    parts = [@title, *@headings.map(&:last)].compact_blank.chunk_while { |a, b| a.casecmp?(b) }.map(&:first)
    parts.shift while parts.size > 1 && parts.join(SEPARATOR).length > MAX_BREADCRUMB_LENGTH
    parts.join(SEPARATOR)
  end
end
