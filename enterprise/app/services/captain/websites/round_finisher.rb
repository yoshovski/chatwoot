# Runs once a discovery round's section labels and page checks are both in: adds the new
# recommended pages when the administrator asked for that, then starts the next round if
# the last one stopped at a limit.
class Captain::Websites::RoundFinisher
  def initialize(source)
    @source = source
  end

  # Call while holding the source's row lock: true for exactly one of the two jobs that finish a round.
  def self.claim?(source)
    stats = source.discovery_stats
    return false unless source.status == 'ready' && stats['verification'] == 'done' && stats['classification'].in?(%w[done failed])
    return false if stats['finished']

    source.update!(discovery_stats: stats.merge('finished' => true))
  end

  def perform
    add_new_pages
    Captain::Websites::DiscoverJob.perform_later(@source.id, 'continue') if @source.discovery_stats['continue']
  end

  private

  # Only pages a later run found are added; pages the administrator already saw and left out stay out.
  def add_new_pages
    return unless @source.auto_add_pages? && @source.selected_urls.any?

    added = new_recommended_urls.first(@source.account.usage_limits[:captain][:documents][:current_available])
    return if added.empty?

    Captain::Websites::SelectionService.new(@source).perform(@source.selected_urls + added)
    @source.update!(discovery_stats: @source.discovery_stats.merge('auto_added' => added.size))
  end

  def new_recommended_urls
    new_urls = @source.discovery_stats['new_urls'].to_a.to_set
    @source.pages.select { |page| new_urls.include?(page['url']) && page['bucket'] == 'recommended' }.pluck('url') - @source.selected_urls
  end
end
