# Learns, per host, the text blocks that discovery saw on a large share of fetched pages:
# menus, banners, newsletter boxes and calls to action that sit outside <nav>/<footer>.
# Version 3 cleaning drops them from every page except the website's start page, so a
# site-wide fact such as a shipping banner is still kept once.
#
# It also learns blocks repeated within one section (host + first path segment), such as an
# ebook banner on every /resources page, which are too rare across the whole host. Those are
# kept only on the section's shortest URL.
class Captain::Websites::BoilerplateLearner
  MIN_PAGES = 4
  MIN_COUNT = 3
  SHARE = 0.3
  SECTION_SHARE = 0.5
  MAX_BLOCKS = 400

  def initialize
    @pages = Hash.new(0)
    @counts = Hash.new { |counts, key| counts[key] = Hash.new(0) }
    @section_urls = Hash.new { |urls, section| urls[section] = [] }
    @section_counts = Hash.new { |counts, key| counts[key] = Hash.new(0) }
  end

  def add(url, block_hashes)
    host = URI.parse(url).host.delete_prefix('www.')
    section = Captain::Websites::PageRules.section(url)
    @pages[host] += 1
    @section_urls[section] << url
    block_hashes.each do |hash|
      @counts[host][hash] += 1
      @section_counts[section][hash] += 1
    end
  end

  def to_h
    @pages.filter_map do |host, pages|
      next if pages < MIN_PAGES

      blocks = frequent(@counts[host], [MIN_COUNT, (pages * SHARE).ceil].max)
      [host, blocks] if blocks.any?
    end.to_h
  end

  # { section => { 'keep' => url, 'blocks' => hashes } }, without blocks the host rule already removes.
  def sections
    site = to_h
    @section_urls.filter_map do |section, urls|
      host_blocks = site.fetch(section.split('/').first, []).to_set
      blocks = frequent(@section_counts[section], [MIN_COUNT, (urls.size * SECTION_SHARE).ceil].max).reject { |hash| host_blocks.include?(hash) }
      [section, { 'keep' => urls.min_by { |url| [url.length, url] }, 'blocks' => blocks }] if blocks.any?
    end.to_h
  end

  private

  def frequent(counts, threshold)
    counts.select { |_, count| count >= threshold }.sort_by { |_, count| -count }.first(MAX_BLOCKS).map(&:first)
  end
end
