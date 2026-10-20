# Learns, per host, the text blocks that discovery saw on a large share of fetched pages:
# menus, banners, newsletter boxes and calls to action that sit outside <nav>/<footer>.
# Version 3 cleaning drops them from every page except the website's start page, so a
# site-wide fact such as a shipping banner is still kept once.
class Captain::Websites::BoilerplateLearner
  MIN_PAGES = 4
  MIN_COUNT = 3
  SHARE = 0.3
  MAX_BLOCKS = 400

  def initialize
    @pages = Hash.new(0)
    @counts = Hash.new { |counts, host| counts[host] = Hash.new(0) }
  end

  def add(url, block_hashes)
    host = URI.parse(url).host.delete_prefix('www.')
    @pages[host] += 1
    block_hashes.each { |hash| @counts[host][hash] += 1 }
  end

  def to_h
    @pages.filter_map do |host, pages|
      next if pages < MIN_PAGES

      threshold = [MIN_COUNT, (pages * SHARE).ceil].max
      blocks = @counts[host].select { |_, count| count >= threshold }.sort_by { |_, count| -count }.first(MAX_BLOCKS).map(&:first)
      [host, blocks] if blocks.any?
    end.to_h
  end
end
