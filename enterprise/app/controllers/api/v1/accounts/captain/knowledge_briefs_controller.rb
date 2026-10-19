class Api::V1::Accounts::Captain::KnowledgeBriefsController < Api::V1::Accounts::BaseController
  before_action -> { authorize(Captain::Assistant, :update?) }
  before_action :set_assistant

  def show
    brief = @assistant.knowledge_brief || @assistant.build_knowledge_brief(account: Current.account)
    render json: brief.client_payload
  end

  def generate
    ids = params.require(:document_ids)
    brief = nil
    @assistant.with_lock do
      brief = @assistant.knowledge_brief || @assistant.create_knowledge_brief!(account: Current.account)
      return head :conflict if brief.status.in?(%w[queued generating]) && brief.updated_at > 20.minutes.ago
      unless Captain::Knowledge::BriefGenerator.valid_document_ids?(ids) && brief.fingerprint(ids)
        return render json: { error: I18n.t('captain.knowledge_briefs.invalid_sources') }, status: :unprocessable_entity
      end

      brief.update!(status: 'queued', error_code: nil)
      Captain::Knowledge::GenerateBriefJob.perform_later(@assistant.id, ids)
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
    return head :unprocessable_entity unless brief&.current?(brief.draft)

    output = draft_params
    @assistant.with_lock do
      brief.lock!
      return head :conflict unless brief.current?(brief.draft) && params[:brief][:revision] == brief.draft['revision']
      unless Captain::Knowledge::BriefGenerator.valid_output?(output, brief.draft.fetch('document_ids'))
        return render json: { error: I18n.t('captain.knowledge_briefs.invalid_draft') }, status: :unprocessable_entity
      end

      publish_brief(brief, output)
    end
    render json: brief.client_payload
  end

  private

  def publish_brief(brief, output)
    brief.update!(published: brief.draft.merge(output))
    @assistant.update!(config: @assistant.config.merge('knowledge_brief_enabled' => true))
  end

  def draft_params
    params.require(:brief).permit(overview: [:text, { document_ids: [] }], topics: [:title, :summary, { document_ids: [] }]).to_h
  end

  def set_assistant
    @assistant = Current.account.captain_assistants.find(params[:assistant_id])
  end
end
