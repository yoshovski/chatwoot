class Api::V1::Accounts::Captain::KnowledgeBriefsController < Api::V1::Accounts::BaseController
  before_action -> { authorize(Captain::Assistant, :update?) }
  before_action :set_assistant

  def show
    brief = @assistant.knowledge_brief || @assistant.build_knowledge_brief(account: Current.account)
    render json: brief.client_payload
  end

  # Previews and starter examples written for this business; nil until the first generation finishes.
  def examples
    brief = @assistant.knowledge_brief || @assistant.create_knowledge_brief!(account: Current.account)
    if brief.examples_due?(refresh: params[:refresh] == 'true')
      brief.update!(examples: brief.examples.merge('requested_at' => Time.current.iso8601))
      Captain::Knowledge::GenerateExamplesJob.perform_later(@assistant.id)
    end
    render json: { examples: brief.examples['data'], generated_at: brief.examples['generated_at'] }
  end

  # Without document_ids the job picks the sources itself. Chosen sources that are still indexing are left out.
  def generate
    ids = params[:document_ids]
    return render_invalid_sources unless ids.nil? || Captain::Knowledge::BriefGenerator.valid_document_ids?(ids)

    brief = nil
    @assistant.with_lock do
      brief = @assistant.knowledge_brief || @assistant.create_knowledge_brief!(account: Current.account)
      return head :conflict if brief.status.in?(%w[queued generating]) && brief.updated_at > 20.minutes.ago
      return render_invalid_sources unless ready_sources?(brief, ids)

      queue_generation(brief, ids)
    end
    render json: brief.client_payload, status: :accepted
  end

  def update
    @assistant.with_lock do
      @assistant.update!(config: @assistant.config.merge('knowledge_brief_enabled' => false))
    end
    render json: @assistant.knowledge_brief&.client_payload || { enabled: false }
  end

  def publish
    brief = @assistant.knowledge_brief
    return head :unprocessable_entity unless brief&.usable?(brief.draft)

    @assistant.with_lock do
      brief.lock!
      return head :conflict unless brief.usable?(brief.draft) && params[:brief][:revision] == brief.draft['revision']

      output = prepared_publish_output(brief)
      unless output && Captain::Knowledge::BriefGenerator.valid_output?(output, allowed_publish_ids(brief))
        return render json: { error: I18n.t('captain.knowledge_briefs.invalid_draft') }, status: :unprocessable_entity
      end

      publish_brief(brief, output)
    end
    render json: brief.client_payload
  end

  private

  def ready_sources?(brief, ids) = (ids ? brief.source_scope.where(id: ids) : brief.source_scope).exists?

  def queue_generation(brief, ids)
    brief.update!(status: 'queued', error_code: nil)
    Captain::Knowledge::GenerateBriefJob.perform_later(@assistant.id, ids, pick_sources: ids.nil?)
  end

  def render_invalid_sources
    render json: { error: I18n.t('captain.knowledge_briefs.invalid_sources') }, status: :unprocessable_entity
  end

  def allowed_publish_ids(brief)
    draft_ids = Array(brief.draft['document_ids']).map(&:to_i)
    offering_ids = Array(brief.draft['offerings']).flat_map { |o| Array(o['evidence']).map { |ev| ev['document_id'].to_i } }
    (draft_ids | offering_ids).uniq
  end

  def prepared_publish_output(brief)
    raw = draft_params
    return unless raw['overview'].is_a?(Hash) && raw['topics'].is_a?(Array)
    return raw unless raw.key?('offerings')

    reconcile_submitted_offerings(brief, raw)
  end

  def reconcile_submitted_offerings(brief, raw)
    allowed_ids = allowed_publish_ids(brief)
    submitted_offerings = Array(raw['offerings'])
    submitted_doc_ids = submitted_offerings.flat_map { |item| Array(item['evidence']).map { |ev| ev['document_id'].to_i } }.uniq
    return if (submitted_doc_ids - allowed_ids).any?

    docs = brief.permitted_documents(allowed_ids).to_a
    reconciled = Captain::Knowledge::OfferingReconciler.new(documents: docs).reconcile(submitted_offerings)
    return if reconciled.size != submitted_offerings.size

    raw.merge(
      'offerings' => reconciled,
      'suggestion_candidates' => Captain::Knowledge::OfferingReconciler.build_suggestion_candidates(
        reconciled, raw['topics'], Array(brief.draft['document_ids'])
      )
    )
  end

  def publish_brief(brief, output)
    brief.update!(published: brief.draft.merge(output))
    @assistant.update!(config: @assistant.config.merge('knowledge_brief_enabled' => true))
  end

  def draft_params
    params.require(:brief).permit(
      overview: [:text, { document_ids: [] }],
      topics: [:title, :summary, { document_ids: [] }],
      offerings: [
        :id, :name, :kind, :purpose, :status, :edited,
        { aliases: [], category_ids: [], audiences: [],
          evidence: [:document_id, :content_fingerprint, :passage_id, :quote, { supports: [] }] }
      ]
    ).to_h
  end

  def set_assistant
    @assistant = Current.account.captain_assistants.find(params[:assistant_id])
  end
end
