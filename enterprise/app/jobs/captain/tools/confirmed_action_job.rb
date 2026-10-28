# Finishes a confirm-mode action after the customer clicks its card: Confirm runs the steps left after the
# confirmation, then posts the action's success or failure message (no second LLM call). Cancel, an expired card or
# one replaced by a newer action posts a short "didn't do it". Each outcome is also left as a private note.
class Captain::Tools::ConfirmedActionJob < ApplicationJob
  queue_as :default

  def perform(conversation, nonce, choice)
    @conversation = conversation
    @assistant = conversation.inbox.captain_assistant
    pending = Captain::Tools::ActionConfirmation.take!(conversation, nonce)
    @tool = pending && conversation.account.captain_custom_tools.enabled.find_by(id: pending['tool_id'])
    return post_cancelled(:expired) if @assistant.blank? || @tool.blank? || Captain::Tools::ActionConfirmation.expired?(pending)
    return post_cancelled(:cancelled) unless choice == Captain::Tools::ActionConfirmation::CONFIRM

    run_remaining_steps(pending)
  end

  private

  def run_remaining_steps(pending)
    result = Captain::Tools::ActionRunner.new(@tool, state: tool_state).run(
      params: pending['params'], contact: contact_values, outputs: pending['outputs'], start_at: pending['start_at'].to_i
    )
    key = result.ok? ? 'success' : 'failure'
    post(Captain::Tools::ActionConfirmation.message(@tool, key, params: pending['params'], outputs: result.outputs, locale: account_locale))
    outcome = result.ok? ? :succeeded : :failed
    post_note(outcome, error: [result.error_kind, result.status].compact.join(' '))
  end

  def post_cancelled(outcome)
    I18n.with_locale(account_locale) { post(I18n.t('captain.action_confirmation.cancelled')) } if @assistant
    post_note(outcome) if @tool
  end

  def post_note(outcome, error: nil)
    I18n.with_locale(account_locale) do
      text = I18n.t('captain.action_confirmation.note', title: @tool.title,
                                                        outcome: I18n.t("captain.action_confirmation.outcomes.#{outcome}", error: error))
      post(text, private: true)
    end
  end

  def post(content, private: false)
    @conversation.messages.create!(content: content, message_type: :outgoing, private: private, account_id: @conversation.account_id,
                                   inbox_id: @conversation.inbox_id, sender: @assistant)
  end

  def tool_state
    { account_id: @conversation.account_id, assistant_id: @assistant.id,
      conversation: { id: @conversation.id, display_id: @conversation.display_id },
      contact: @conversation.contact&.slice(:id, :email, :phone_number)&.symbolize_keys,
      contact_inbox: @conversation.contact_inbox&.slice(:id, :hmac_verified)&.symbolize_keys }
  end

  def contact_values
    contact = @conversation.contact
    { email: contact&.email, phone_number: contact&.phone_number, name: contact&.name,
      verified: @conversation.contact_inbox&.hmac_verified == true }
  end

  def account_locale = @conversation.account.locale
end
