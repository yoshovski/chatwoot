# Backs the guided setup stepper: website → knowledge import → test → go live → install. Each step reuses the regular
# APIs where they exist; these actions only cover what needs the account as a whole.
class Api::V1::Accounts::Captain::GuidedSetupController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?

  def show
    render json: state.payload
  end

  def website
    Captain::GuidedSetup::WebsiteStarter.new(Current.account, params.require(:url)).perform
    render json: state.payload, status: :accepted
  rescue ActiveRecord::RecordInvalid
    render json: { error: I18n.t('captain.guided_setup.invalid_url') }, status: :unprocessable_entity
  end

  def go_live
    assistant = state.assistant
    status = Captain::GuidedSetup::Readiness.status(assistant)
    return render_error('not_ready', status) unless Captain::GuidedSetup::Readiness.live_ready?(status)

    inbox = state.widget_inbox || create_widget_inbox
    return render_error('invalid_url', status) unless inbox

    connected = CaptainInbox.find_by(inbox: inbox)
    return render_error('inbox_taken', status) if connected && connected.captain_assistant_id != assistant.id

    assistant.captain_inboxes.create!(inbox: inbox) unless connected
    render json: state.payload
  end

  def check_installation
    inbox = state.widget_inbox
    return head :not_found unless inbox

    render json: { status: Captain::GuidedSetup::InstallationCheck.new(inbox).perform }
  end

  private

  def state
    @state ||= Captain::GuidedSetup::State.new(Current.account)
  end

  # Uses the account website, which the website step stored when it was blank.
  def create_widget_inbox
    Onboarding::WebWidgetCreationService.new(Current.account, Current.user).perform
  end

  def render_error(key, status)
    render json: { error: I18n.t("captain.guided_setup.#{key}"), readiness: status }, status: :unprocessable_entity
  end
end
