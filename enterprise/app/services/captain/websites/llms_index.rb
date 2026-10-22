# Documentation platforms (ReadMe, Mintlify, GitBook, Fern, …) publish /llms.txt: an index of their pages
# that links each page's markdown copy. The copy carries the page's full text and API definitions without
# the rendered consoles, language tabs and navigation, so imports read it instead of the HTML page.
class Captain::Websites::LlmsIndex
  # "- [Title](https://…/page.md): description"; titles may hold one level of brackets ("Android [Deprecated]").
  ENTRY = /^[ \t]*[-*][ \t]*\[((?:[^\[\]\n]|\[[^\]\n]*\])+)\]\(([^)\s]+\.md)\)(?:[ \t]*:[ \t]*(.+))?$/
  DESCRIPTION_LENGTH = 200

  # Page hashes for each markdown link, keyed to the HTML page the copy belongs to.
  def self.pages(text, origin)
    text.to_s.scan(ENTRY).filter_map do |title, link, description|
      markdown_url = Captain::Websites::UrlPolicy.normalize(link, base: origin)
      next unless markdown_url&.end_with?('.md')

      { 'url' => markdown_url.delete_suffix('.md'), 'markdown_url' => markdown_url, 'title' => title.strip.first(255),
        'description' => description&.strip&.first(DESCRIPTION_LENGTH) }.compact
    end
  end

  # The markdown copy as an import result; nil when it has no text, so the HTML page is read instead.
  def self.page(markdown_url)
    text = SafeFetch.fetch(markdown_url, validate_content_type: false, max_bytes: Captain::Websites::PoliteFetcher::MAX_BYTES, read_timeout: 10,
                                         headers: { 'User-Agent' => "#{Captain::Websites::RobotsPolicy::AGENT}/1.0" }) do |result|
      result.tempfile.read
    end
    content = Captain::Knowledge::OpenApiMarkdown.convert(text.force_encoding(Encoding::UTF_8).scrub.sub(/\A---\n.*?\n---\n/m, '')).strip
    return if content.empty?

    Captain::Documents::SinglePageFetcher::Result.new(
      success: true, title: content[/^#[ \t]+(.+)$/, 1]&.strip&.first(Captain::Documents::SinglePageFetcher::TITLE_MAX_LENGTH),
      content: content.first(Captain::Documents::SinglePageFetcher::CONTENT_MAX_LENGTH), faqs: []
    )
  end
end
