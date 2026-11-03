# What one reply is composed for. channel is :widget (also the playground, which has no conversation), :email or
# :messaging. first_ai_reply comes from the run state (nil when the run did not record it).
Captain::Reply::Context = Data.define(:assistant, :conversation, :run_result, :customer_message, :channel, :first_ai_reply,
                                      :suppress_suggestions, :followup_form_requested, :action_confirmation) do
  def self.build(assistant:, run_result:, conversation: nil, customer_message: nil, suppress_suggestions: false)
    state = run_result&.context&.dig(:state)
    new(assistant: assistant, conversation: conversation, run_result: run_result, customer_message: customer_message,
        channel: channel_for(conversation), first_ai_reply: state&.dig(:first_ai_reply),
        suppress_suggestions: suppress_suggestions, followup_form_requested: state&.dig(:lead_followup_form_requested) == true,
        action_confirmation: state&.dig(Captain::Tools::ActionConfirmation::STATE_KEY))
  end

  def self.channel_for(conversation)
    case conversation&.inbox&.channel_type
    when nil, 'Channel::WebWidget' then :widget
    when 'Channel::Email' then :email
    else :messaging
    end
  end

  def widget? = channel == :widget

  def email? = channel == :email

  def state = run_result&.context&.dig(:state)
end
