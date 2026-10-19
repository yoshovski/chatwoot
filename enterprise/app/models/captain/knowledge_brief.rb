class Captain::KnowledgeBrief < ApplicationRecord
  self.table_name = 'captain_knowledge_briefs'

  belongs_to :account
  belongs_to :assistant, class_name: 'Captain::Assistant'
  before_validation -> { self.account = assistant.account if assistant }
  validates :status, inclusion: { in: %w[idle queued generating ready failed] }

  def source_scope
    scope = assistant.documents.enabled.available.where(agents_only: false).where.not(content: [nil, ''])
    return scope unless account.dify_knowledge_enabled?

    scope.where("metadata->>'dify_indexing_status' = 'completed'")
  end

  def fingerprint(ids)
    rows = source_scope.where(id: ids).order(:id).pluck(:id, :name, Arel.sql('md5(content)'))
    return unless rows.size == ids.uniq.size && rows.any?

    Digest::SHA256.hexdigest(rows.to_json)
  end

  def current?(snapshot)
    ids = snapshot['document_ids']
    return false unless ids.is_a?(Array) && ids.any? && snapshot['source_fingerprint'].present?

    fingerprint(ids) == snapshot['source_fingerprint']
  end

  def prompt_context
    return {} unless current?(published)

    { business_overview: published.fetch('overview'), topic_summaries: published.fetch('topics') }
  end

  def client_payload
    as_json(only: %i[status draft published error_code generated_at]).merge(
      'enabled' => assistant.config['knowledge_brief_enabled'] == true,
      'recoverable' => status.in?(%w[queued generating]) && updated_at < 20.minutes.ago,
      'draft_current' => current?(draft), 'published_current' => current?(published),
      'sources' => source_scope.order(:name).pluck(:id, :name, :external_link).map { |id, name, url| { id: id, name: name, url: url } }
    )
  end
end
