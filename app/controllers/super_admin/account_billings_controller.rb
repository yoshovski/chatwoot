# The billing actions on an account's Super Admin page (T10). Enterprise::Billing::AdminActionService does the work and
# records who did it.
class SuperAdmin::AccountBillingsController < SuperAdmin::ApplicationController
  before_action { head :not_found unless ChatwootApp.enterprise? }
  before_action :fetch_account

  def extend_trial
    perform { service.extend_trial(params[:days]) }
  end

  def grant_trial
    perform { service.grant_trial }
  end

  def add_extra_conversations
    perform { service.add_extra_conversations(params[:amount], params[:note]) }
  end

  def apply_coupon
    perform { service.apply_coupon(params[:coupon]) }
  end

  def pause_ai
    perform { service.pause_ai }
  end

  def resume_ai
    perform { service.resume_ai }
  end

  def replay_event
    perform { service.replay_event(params[:stripe_event_id]) }
  end

  private

  def fetch_account
    @account = Account.find(params[:account_id])
  end

  def service
    Enterprise::Billing::AdminActionService.new(account: @account, actor: current_super_admin)
  end

  def perform
    yield
    redirect_to back_to_billing, notice: I18n.t("super_admin.account_billing.done.#{action_name}")
  rescue Enterprise::Billing::AdminActionService::Refused => e
    redirect_to back_to_billing, alert: I18n.t("super_admin.account_billing.refused.#{e.message}")
  rescue ActiveRecord::RecordInvalid => e
    redirect_to back_to_billing, alert: e.record.errors.full_messages.to_sentence
  rescue Stripe::StripeError => e
    # Stripe's message names the problem (for example an unknown coupon); it carries no secret.
    redirect_to back_to_billing, alert: I18n.t('super_admin.account_billing.stripe_failed', error: e.message)
  end

  def back_to_billing
    "#{super_admin_account_path(@account)}#billing"
  end
end
