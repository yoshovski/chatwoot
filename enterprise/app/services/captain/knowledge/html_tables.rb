# Documentation markdown often embeds HTML or MDX tables (`<Table>` … `<td>` spread over many lines with blank
# lines between). Cleaning and chunking split those into scattered tag fragments, so each one becomes a pipe
# table and every row stays one line that pairs a label with its value.
class Captain::Knowledge::HtmlTables
  TABLE = %r{<table\b[^>]*>.*?</table>}mi

  def self.convert(markdown) = markdown.gsub(TABLE) { |html| pipe_table(Nokogiri::HTML.fragment(html)) || html }

  def self.pipe_table(fragment)
    rows = fragment.css('tr').map { |row| row.css('th, td').map { |cell| cell.text.squish.gsub('|', '\\|') } }.reject(&:empty?)
    return if rows.empty?

    width = rows.map(&:size).max
    [rows.first, Array.new(width, '---'), *rows.drop(1)].map { |cells| "| #{cells.fill('', cells.size...width).join(' | ')} |" }.join("\n")
  end
end
