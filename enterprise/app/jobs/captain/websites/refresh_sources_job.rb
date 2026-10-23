# Hourly: looks for new pages on websites whose administrator turned on adding new recommended
# pages, once a week after the last discovery.
class Captain::Websites::RefreshSourcesJob < ApplicationJob
  queue_as :low

  REFRESH_AFTER = 7.days

  def perform
    Captain::WebsiteSource.where(auto_add_pages: true, status: 'ready').where(discovered_at: ...REFRESH_AFTER.ago)
                          .where.not(selected_urls: []).find_each do |source|
      Captain::Websites::DiscoverJob.perform_later(source.id, 'refresh')
    end
  end
end
