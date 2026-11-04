# Posts a scheduled follow-up in the chat: the template's text, or one the AI writes from the scenario's instructions.
class Captain::ScheduledActions::FollowUpMessageHandler
  ATTRIBUTE_VALUE = 'follow_up'.freeze

  def initialize(action)
    @action = action
    @conversation = action.conversation
    @assistant = action.assistant
  end

  def perform
    @conversation.messages.create!(
      content: content, content_type: 'text', message_type: :outgoing, account_id: @conversation.account_id,
      inbox_id: @conversation.inbox_id, sender: @assistant, preserve_waiting_since: true,
      additional_attributes: { 'agent_name' => @assistant.agent_name, Captain::Conversation::CheckInState::ATTRIBUTE_KEY => ATTRIBUTE_VALUE }
    )
  end

  private

  def content
    template = @action.payload['template']
    return Captain::EmailTemplates.new(@assistant).render(template, @conversation)[:body] if template.present?

    Captain::Conversation::CheckInService.new(conversation: @conversation, assistant: @assistant, brief: @action.payload['instructions']).perform
  end
end
