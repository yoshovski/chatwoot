# Keeps business profiles in step with new knowledge without the owner pressing Generate, and retries failed drafts.
# A new draft is only a suggestion: the published profile changes when the owner turns it on.
class Captain::Knowledge::RefreshBriefsJob < ApplicationJob
  queue_as :low

  def perform
    Captain::KnowledgeBrief.where.not(status: %w[queued generating]).includes(:assistant).find_each do |brief|
      next unless brief.refresh_due?

      brief.update!(status: 'queued', error_code: nil)
      Captain::Knowledge::GenerateBriefJob.perform_later(brief.assistant_id, nil, pick_sources: true)
    end
  end
end
