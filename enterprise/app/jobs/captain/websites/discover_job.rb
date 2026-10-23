class Captain::Websites::DiscoverJob < MutexApplicationJob
  queue_as :low
  discard_on ActiveRecord::RecordNotFound

  def perform(source_id, mode = 'fresh')
    with_lock("captain_website_discovery:#{source_id}", 2.hours) do
      source = Captain::WebsiteSource.find(source_id)
      Captain::Websites::DiscoveryService.new(source, mode: mode).perform
    end
  rescue LockAcquisitionError
    nil
  end
end
