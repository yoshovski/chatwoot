# Applies one action to every document of the chosen sections. Website pages are also removed from or
# added back to their website selection, so the page picker and imports agree with the documents.
class Captain::Documents::SectionActions
  ACTIONS = %w[pause resume retry suggest_faqs delete].freeze

  def initialize(assistant, documents)
    @assistant = assistant
    @documents = documents
  end

  # Returns how many documents the action applied to.
  def perform(action)
    raise ArgumentError, "Unknown section action #{action}" unless ACTIONS.include?(action)

    send(action)
  end

  private

  def pause
    update_selection(website_urls) { |selected, urls| selected - urls }
    toggle(enabled: false)
  end

  def resume
    update_selection(website_urls) { |selected, urls| selected | urls }
    toggle(enabled: true)
  end

  def toggle(enabled:)
    @documents.where(enabled: !enabled).find_each.count { |document| document.update!(enabled: enabled) }
  end

  def retry
    @documents.sync_failed.find_each.count { |document| Captain::Documents::SyncRequest.new(document).perform == :queued }
  end

  def suggest_faqs
    @documents.available.where.not(content: [nil, '']).find_each.count do |document|
      next false if document.pdf_document?

      Captain::Documents::ResponseBuilderJob.perform_later(document, force_ai: true)
    end
  end

  def delete
    update_selection(website_urls) { |selected, urls| selected - urls }
    @documents.find_each.count(&:destroy!)
  end

  def website_urls
    @website_urls ||= @documents.where("metadata->>'website_source_id' IS NOT NULL")
                                .pluck(Arel.sql("metadata->>'website_source_id'"), :external_link)
                                .group_by(&:first).transform_values { |pairs| pairs.map(&:last) }
  end

  # A page can only be selected while its source still lists it.
  def update_selection(urls_by_source)
    @assistant.website_sources.where(id: urls_by_source.keys).find_each do |source|
      source.with_lock do
        selected = yield(source.selected_urls, urls_by_source.fetch(source.id.to_s))
        source.update!(selected_urls: selected & source.selectable_urls)
      end
    end
  end
end
