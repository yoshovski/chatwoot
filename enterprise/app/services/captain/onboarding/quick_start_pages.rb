# Quick-start documents answer while the full website import runs. A selected page is re-imported over its quick-start
# copy (ImportPageJob clears the mark); once no selected page is still waiting for its first import, the quick-start
# copies the owner did not select are removed.
class Captain::Onboarding::QuickStartPages
  def initialize(source)
    @source = source
  end

  def retire_unselected
    documents = @source.assistant.documents.where("metadata->>'website_source_id' = ?", @source.id.to_s)
    return if @source.selected_urls.empty? || documents.exists?(external_link: @source.selected_urls, last_sync_attempted_at: nil)

    documents.where("metadata->>'quick_start' = 'true'").where.not(external_link: @source.selected_urls).destroy_all
  end
end
