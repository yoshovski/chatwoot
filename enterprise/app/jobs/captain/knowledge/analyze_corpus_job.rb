class Captain::Knowledge::AnalyzeCorpusJob < ApplicationJob
  queue_as :low
  discard_on ActiveRecord::RecordNotFound

  def perform(assistant_id, token_budget: nil, batch_size: Captain::Knowledge::DocumentAnalyzer::DEFAULT_BATCH_SIZE)
    assistant = Captain::Assistant.find(assistant_id)
    run = Captain::Knowledge::DocumentAnalyzer.analyze_corpus(
      assistant: assistant,
      token_budget: token_budget,
      batch_size: batch_size
    )
    return unless run.status == 'running'

    self.class.perform_later(assistant.id, token_budget: token_budget, batch_size: batch_size)
  end
end
