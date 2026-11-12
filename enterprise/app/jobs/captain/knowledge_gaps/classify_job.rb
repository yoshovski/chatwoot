class Captain::KnowledgeGaps::ClassifyJob < ApplicationJob
  queue_as :low
  # A gap left unclassified after the last attempt stays hidden until the backfill task runs again.
  retry_on Captain::KnowledgeGaps::Classifier::InvalidOutput, RubyLLM::Error, Faraday::Error, wait: :polynomially_longer, attempts: 3

  def perform(gap)
    Captain::KnowledgeGaps::Classification.new(gap).perform
  end
end
