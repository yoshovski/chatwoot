class Captain::Websites::ClassifySectionsJob < ApplicationJob
  queue_as :low
  discard_on ActiveRecord::RecordNotFound

  # run identifies the discovery that requested labels; a newer discovery makes them stale.
  def perform(source_id, run)
    source = Captain::WebsiteSource.find(source_id)
    return unless current?(source, run)

    stats = begin
      labels = Captain::Websites::SectionClassifier.new(source).perform
      { 'sections' => labels['sections'], 'page_labels' => labels['pages'], 'classification' => 'done' }
    rescue StandardError => e
      # URL and content rules already sorted the pages; labels only refine them.
      Rails.logger.warn "[Captain][WebsiteClassification] source_id=#{source.id} error=#{e.class.name}"
      { 'classification' => 'failed' }
    end
    source.with_lock do
      next unless current?(source, run)

      source.discovery_stats = source.discovery_stats.merge(stats)
      source.update!(pages: Captain::Websites::PageBuckets.new(source).perform(source.pages))
    end
  end

  private

  def current?(source, run) = source.status == 'ready' && source.discovery_stats['run'] == run
end
