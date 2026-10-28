# The pending action of a confirm-mode custom tool: the AI's call runs only the steps before the first one that
# changes data, stores what the rest needs on the conversation and shows a Confirm/Cancel card. The customer's click
# (CaptainListener) claims it once; Confirm runs the remaining steps in ConfirmedActionJob.
module Captain::Tools::ActionConfirmation
  PENDING_KEY = 'captain_pending_action'.freeze
  NONCE_ATTRIBUTE = 'captain_action_confirmation'.freeze
  HANDLED_ATTRIBUTE = 'captain_action_handled'.freeze
  STATE_KEY = :captain_action_confirmation
  TTL = 15.minutes
  # Only the web widget sends a card click back as an update of the card, which is what claims the action.
  BUTTON_CHANNELS = %w[Channel::WebWidget].freeze
  CONFIRM = 'confirm'.freeze
  CANCEL = 'cancel'.freeze

  module_function

  def buttons_supported?(state)
    BUTTON_CHANNELS.include?(state[:channel_type]) || state[:source] == 'playground'
  end

  # Leading verify steps and GET requests run before the customer confirms, so the card names something real.
  def steps_before_confirmation(tool)
    tool.steps.index { |step| step['type'] == 'request' && step['method'] != 'GET' } || tool.steps.size
  end

  # One pending action per conversation; a new one replaces the old, so the old card's nonce no longer matches.
  def store!(conversation, tool:, params:, outputs:, start_at:)
    nonce = SecureRandom.hex(16)
    pending = { 'nonce' => nonce, 'tool_id' => tool.id, 'params' => params, 'outputs' => outputs, 'start_at' => start_at,
                'expires_at' => TTL.from_now.iso8601 }
    conversation.with_lock do
      attributes = conversation.additional_attributes.to_h.merge(PENDING_KEY => pending)
      conversation.update_columns(additional_attributes: attributes) # rubocop:disable Rails/SkipsModelValidations
    end
    nonce
  end

  # Removes and returns the pending action when it is still the one this nonce belongs to.
  def take!(conversation, nonce)
    conversation.with_lock do
      pending = conversation.additional_attributes.to_h[PENDING_KEY]
      next nil unless pending.is_a?(Hash) && ActiveSupport::SecurityUtils.secure_compare(pending['nonce'].to_s, nonce.to_s)

      conversation.update_columns(additional_attributes: conversation.additional_attributes.except(PENDING_KEY)) # rubocop:disable Rails/SkipsModelValidations
      pending
    end
  end

  def expired?(pending) = Time.zone.parse(pending['expires_at'].to_s).nil? || Time.zone.parse(pending['expires_at']).past?

  def card_payload(confirmation, locale)
    I18n.with_locale(locale) do
      items = [{ title: I18n.t('captain.action_confirmation.confirm'), value: CONFIRM },
               { title: I18n.t('captain.action_confirmation.cancel'), value: CANCEL }]
      { content: confirmation['content'], content_type: 'input_select',
        content_attributes: { :items => items, NONCE_ATTRIBUTE => confirmation['nonce'] } }
    end
  end

  # Renders one of the action's messages (confirm_prompt, success, failure), or the default text when it is blank
  # or fails to render.
  def message(tool, key, params:, outputs:, locale:)
    I18n.with_locale(locale) do
      default = I18n.t("captain.action_confirmation.#{key}", title: tool.title.to_s.sub(/\A[[:upper:]](?![[:upper:]])/, &:downcase))
      template = tool.messages.to_h[key]
      next default if template.blank?

      context = params.to_h.merge('outputs' => tool.outputs.to_h { |output| [output['key'], nil] }.merge(outputs.to_h))
      tool.send(:render_template, template, context).presence || default
    rescue StandardError
      default
    end
  end
end
