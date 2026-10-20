class Captain::Knowledge::GenerateBriefJob < MutexApplicationJob
  queue_as :low
  discard_on ActiveRecord::RecordNotFound

  # document_ids nil refreshes the published sources; pick_sources lets the model choose them.
  def perform(assistant_id, document_ids = nil, pick_sources: false)
    assistant = Captain::Assistant.find(assistant_id)
    brief = assistant.knowledge_brief
    return unless brief

    with_lock("captain_knowledge_brief:#{assistant_id}", 20.minutes) do
      brief.reload
      return if document_ids.nil? && !pick_sources && skip_refresh?(assistant, brief)

      generate(brief, document_ids, pick_sources)
    end
  rescue LockAcquisitionError
    nil
  rescue StandardError => e
    brief&.update!(status: 'failed', error_code: 'generation_failed')
    Rails.logger.warn "[Captain][KnowledgeBrief] assistant_id=#{assistant_id} error=#{e.class.name}"
  end

  private

  def generate(brief, document_ids, pick_sources)
    return Captain::Knowledge::BriefGenerator.new(brief).perform(document_ids || brief.published['document_ids']) unless pick_sources

    picker = Captain::Knowledge::BriefSourcePicker.new(brief)
    Captain::Knowledge::BriefGenerator.new(brief).perform(picker.perform, reasons: picker.reasons)
  end

  def skip_refresh?(assistant, brief)
    return true unless assistant.reload.config['knowledge_brief_enabled'] == true
    return true if brief.status.in?(%w[queued generating]) && brief.updated_at > 20.minutes.ago

    return false unless brief.draft['document_ids'] == brief.published['document_ids'] && brief.current?(brief.draft)

    brief.update!(status: 'ready', error_code: nil)
    true
  end
end
