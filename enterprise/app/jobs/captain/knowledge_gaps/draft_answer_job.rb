class Captain::KnowledgeGaps::DraftAnswerJob < ApplicationJob
  queue_as :low

  def perform(gap)
    Captain::KnowledgeGaps::DraftAnswer.new(gap).perform
  end
end
