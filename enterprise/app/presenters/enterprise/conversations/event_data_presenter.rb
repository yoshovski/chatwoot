module Enterprise::Conversations::EventDataPresenter
  def push_data
    return super unless account.feature_enabled?('sla')

    sla_applicable = sla_applicable?

    super.merge(
      applied_sla: sla_applicable ? applied_sla&.push_event_data : nil,
      sla_events: sla_applicable ? sla_events.map(&:push_event_data) : [],
      sla_policy_id: sla_applicable ? sla_policy_id : nil
    )
  end

  private

  def push_meta
    assistant = captain_waiting_assistant
    return super if assistant.blank?

    super.merge(captain_waiting: { id: assistant.id, name: assistant.name, thumbnail: assistant.push_event_data[:avatar_url] })
  end
end
