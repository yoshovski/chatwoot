class Api::V1::Accounts::Captain::DocumentSectionsController < Api::V1::Accounts::BaseController
  before_action -> { check_authorization(Captain::Assistant) }
  before_action :set_assistant

  def index
    render json: { sections: sections.groups }
  end

  # Applies one action (pause, resume, retry, suggest_faqs, delete) to every document of the sections.
  def create
    keys = params[:sections]
    action = params[:section_action]
    unless keys.is_a?(Array) && keys.any? && keys.all?(String) && Captain::Documents::SectionActions::ACTIONS.include?(action)
      return render json: { error: I18n.t('captain.documents.invalid_section_action') }, status: :unprocessable_entity
    end

    count = Captain::Documents::SectionActions.new(@assistant, sections.documents(keys)).perform(action)
    render json: { count: count }
  end

  private

  def set_assistant
    @assistant = Current.account.captain_assistants.find(params[:assistant_id])
  end

  def sections = @sections ||= Captain::Documents::Sections.new(@assistant)
end
