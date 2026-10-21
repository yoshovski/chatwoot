class Captain::Knowledge::GenerateExamplesJob < MutexApplicationJob
  queue_as :low
  discard_on ActiveRecord::RecordNotFound

  def perform(assistant_id)
    brief = Captain::Assistant.find(assistant_id).knowledge_brief
    return unless brief

    with_lock("captain_knowledge_examples:#{assistant_id}", 5.minutes) do
      Captain::Knowledge::ExamplesGenerator.new(brief.reload).perform
    end
  rescue LockAcquisitionError
    nil
  rescue StandardError => e
    Rails.logger.warn "[Captain][KnowledgeExamples] assistant_id=#{assistant_id} error=#{e.class.name}"
  end
end
