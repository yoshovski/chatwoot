class Captain::Knowledge::GenerateBriefJob < MutexApplicationJob
  queue_as :low
  discard_on ActiveRecord::RecordNotFound

  def perform(assistant_id, document_ids = nil)
    assistant = Captain::Assistant.find(assistant_id)
    brief = assistant.knowledge_brief
    return unless brief

    with_lock("captain_knowledge_brief:#{assistant_id}", 20.minutes) do
      brief.reload
      return if document_ids.nil? && skip_refresh?(assistant, brief)

      ids = document_ids || brief.published['document_ids']
      Captain::Knowledge::BriefGenerator.new(brief).perform(ids)
    end
  rescue LockAcquisitionError
    nil
  rescue StandardError => e
    brief&.update!(status: 'failed', error_code: 'generation_failed')
    Rails.logger.warn "[Captain][KnowledgeBrief] assistant_id=#{assistant_id} error=#{e.class.name}"
  end

  private

  def skip_refresh?(assistant, brief)
    return true unless assistant.reload.config['knowledge_brief_enabled'] == true
    return true if brief.status.in?(%w[queued generating]) && brief.updated_at > 20.minutes.ago

    return false unless brief.draft['document_ids'] == brief.published['document_ids'] && brief.current?(brief.draft)

    brief.update!(status: 'ready', error_code: nil)
    true
  end
end
