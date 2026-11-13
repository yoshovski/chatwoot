class Captain::Leads::DeliveryService
  def initialize(assistant, conversation)
    @assistant = assistant
    @conversation = conversation
  end

  def perform(lead_type:, summary:, fields: {}, notify: true)
    @conversation.with_lock do
      note = upsert_note(summary) if @assistant.lead_private_note?
      apply_labels(lead_type)
      lead = { 'type' => lead_type, 'summary' => summary, 'fields' => fields.to_h }
      attributes = Captain::Conversation::Summary.new(@conversation).merged_attributes('status' => 'lead', 'lead' => lead)
                                                 .except('business_handoff', 'business_followup').merge('business_lead_captured' => true)
      attributes['business_lead_summary_note_id'] = note.id if note
      @conversation.update!(additional_attributes: attributes)
    end
    Captain::Leads::NotifyTeamJob.perform_later(@assistant.id, @conversation.id) if notify && @assistant.config['lead_notification_team_id']
  end

  private

  def upsert_note(summary)
    notes = @conversation.messages.where(private: true)
    note = notes.find_by(id: @conversation.additional_attributes['business_lead_summary_note_id']) || notes.find_by(content: summary)
    note ||= @conversation.messages.build(account: @assistant.account, inbox: @conversation.inbox, sender: @assistant,
                                          message_type: :outgoing, private: true)
    note.update!(content: summary)
    note
  end

  def apply_labels(lead_type)
    type_key = lead_type.tr('_', '-')
    labels = ['prospect', type_key, type_key.downcase].uniq
    @conversation.add_labels(@assistant.account.labels.where(title: labels).pluck(:title))
  end
end
