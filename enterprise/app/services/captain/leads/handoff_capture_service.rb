# A signed, conversation-bound business inquiry survives the handoff while the form collects identity.
# Nothing is captured or sent to the CRM until a real name and email are available.
class Captain::Leads::HandoffCaptureService
  PURPOSE = 'captain_business_handoff'.freeze

  def initialize(conversation, assistant)
    @conversation = conversation
    @assistant = assistant
  end

  def stage!(lead_type:, summary:, fields:)
    return unless enabled?

    Captain::Leads::CaptureService.new(@assistant, @conversation.contact).validate_qualification!(lead_type, summary, fields)
    payload = { 'conversation_id' => @conversation.id, 'account_id' => @assistant.account_id, 'assistant_id' => @assistant.id,
                'lead_type' => lead_type, 'summary' => summary, 'fields' => fields }
    @conversation.with_lock do
      return if @conversation.additional_attributes['business_lead_captured']

      @conversation.update!(additional_attributes: @conversation.additional_attributes.merge(
        'business_handoff' => verifier.generate(payload, purpose: PURPOSE, expires_in: 7.days)
      ))
    end
    complete!
  end

  def complete!
    return unless enabled?

    @conversation.with_lock do
      payload = verified_payload
      return unless payload

      contact = @conversation.contact.reload
      return if Captain::Conversation::ContactCaptureService.missing_name?(contact) || contact.email.blank?

      capture!(contact, payload)
    end
    Captain::Leads::NotifyTeamJob.perform_later(@assistant.id, @conversation.id) if @assistant.config['lead_notification_team_id']
  end

  private

  def verified_payload
    payload = verifier.verified(@conversation.additional_attributes['business_handoff'], purpose: PURPOSE)
    payload if payload && payload.values_at('conversation_id', 'account_id', 'assistant_id') ==
                          [@conversation.id, @assistant.account_id, @assistant.id]
  end

  def capture!(contact, payload)
    Captain::Leads::CaptureService.new(@assistant, contact).perform(
      name: contact.name, email: contact.email, lead_type: payload['lead_type'], summary: payload['summary'], fields: payload['fields']
    )
    note = @conversation.messages.create!(account: @assistant.account, inbox: @conversation.inbox, sender: @assistant,
                                          message_type: :outgoing, private: true, content: payload['summary'])
    labels = ['prospect', payload['lead_type'].tr('_', '-')]
    @conversation.add_labels(@assistant.account.labels.where(title: labels).pluck(:title))
    attributes = @conversation.additional_attributes.except('business_handoff').merge(
      'business_lead_captured' => true, 'business_lead_summary_note_id' => note.id
    )
    @conversation.update!(additional_attributes: attributes)
  end

  def enabled?
    @assistant&.leads_enabled? && @assistant.config['lead_handoff_capture_enabled'] == true && @conversation.account_id == @assistant.account_id
  end

  def verifier = Rails.application.message_verifier(PURPOSE)
end
