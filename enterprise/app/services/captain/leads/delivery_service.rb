class Captain::Leads::DeliveryService
  def initialize(assistant, conversation)
    @assistant = assistant
    @conversation = conversation
  end

  def perform(lead_type:, summary:, notify: true)
    @conversation.with_lock do
      notes = @conversation.messages.where(private: true)
      note = notes.find_by(id: @conversation.additional_attributes['business_lead_summary_note_id']) || notes.find_by(content: summary)
      note ||= @conversation.messages.build(account: @assistant.account, inbox: @conversation.inbox, sender: @assistant,
                                            message_type: :outgoing, private: true)
      note.update!(content: summary)
      apply_labels(lead_type)
      attributes = @conversation.additional_attributes.except('business_handoff', 'business_followup').merge(
        'business_lead_captured' => true, 'business_lead_summary_note_id' => note.id
      )
      @conversation.update!(additional_attributes: attributes)
    end
    Captain::Leads::NotifyTeamJob.perform_later(@assistant.id, @conversation.id) if notify && @assistant.config['lead_notification_team_id']
  end

  private

  def apply_labels(lead_type)
    type_key = lead_type.tr('_', '-')
    labels = ['prospect', type_key, type_key.downcase].uniq
    @conversation.add_labels(@assistant.account.labels.where(title: labels).pluck(:title))
  end
end
