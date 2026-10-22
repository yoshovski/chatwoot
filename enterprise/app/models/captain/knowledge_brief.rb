class Captain::KnowledgeBrief < ApplicationRecord
  self.table_name = 'captain_knowledge_briefs'
  EXAMPLE_DOCUMENTS = 30
  EXAMPLES_VERSION = 2
  # New agents and unpublished briefs change quickly; settled agents refresh their examples at most monthly.
  EXAMPLES_SETTLING_AGE = 14.days
  EXAMPLES_SETTLING_INTERVAL = 1.hour
  EXAMPLES_SETTLED_INTERVAL = 30.days

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

  # Approved text stays in use while every source still exists, is enabled and is public.
  # Content edits only mark it for review (sources_changed) and queue a replacement draft.
  def usable?(snapshot)
    ids = snapshot['document_ids']
    return false unless ids.is_a?(Array) && ids.any?

    assistant.documents.enabled.where(agents_only: false, id: ids).count == ids.uniq.size
  end

  def current?(snapshot)
    ids = snapshot['document_ids']
    return false unless ids.is_a?(Array) && ids.any? && snapshot['source_fingerprint'].present?

    fingerprint(ids) == snapshot['source_fingerprint']
  end

  def prompt_context
    return {} unless usable?(published)

    { business_overview: published.fetch('overview'), topic_summaries: published.fetch('topics') }
  end

  def examples_input
    snapshot = usable?(published) ? published : draft
    {
      name: assistant.name, product_name: assistant.config['product_name'], description: assistant.description,
      overview: snapshot.dig('overview', 'text'), topics: Array(snapshot['topics']).pluck('title'),
      documents: source_scope.order(updated_at: :desc).limit(EXAMPLE_DOCUMENTS).pluck(:name)
    }
  end

  # Bumping EXAMPLES_VERSION regenerates every agent's examples, at the settling pace, after a prompt change.
  def examples_fingerprint(input = examples_input) = Digest::SHA256.hexdigest([EXAMPLES_VERSION, input].to_json)

  # Regenerates only when the business details changed and the last request is older than the interval.
  def examples_due?
    return false if examples['fingerprint'] == examples_fingerprint

    requested_at = examples['requested_at']
    requested_at.nil? || Time.zone.parse(requested_at) < examples_interval.ago
  end

  def examples_interval
    settling = assistant.created_at > EXAMPLES_SETTLING_AGE.ago || !usable?(published) || examples['version'] != EXAMPLES_VERSION
    settling ? EXAMPLES_SETTLING_INTERVAL : EXAMPLES_SETTLED_INTERVAL
  end

  def client_payload
    as_json(only: %i[status draft published error_code generated_at]).merge(
      'enabled' => assistant.config['knowledge_brief_enabled'] == true,
      'recoverable' => status.in?(%w[queued generating]) && updated_at < 20.minutes.ago,
      'draft_usable' => usable?(draft), 'published_usable' => usable?(published),
      'sources_changed' => usable?(published) && !current?(published),
      'sources' => source_scope.order(:name).pluck(:id, :name, :external_link).map do |id, name, url|
        { id: id, name: name, url: url, section: Captain::Documents::Sections.key_for(url) }
      end
    )
  end
end
