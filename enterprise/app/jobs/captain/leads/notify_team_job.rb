class Captain::Leads::NotifyTeamJob < MutexApplicationJob
  queue_as :medium
  retry_on(*ExceptionList::SMTP_EXCEPTIONS, wait: :polynomially_longer, attempts: 5)
  retry_on LockAcquisitionError, wait: 5.seconds, attempts: 5

  def perform(assistant_id, conversation_id)
    assistant = Captain::Assistant.find_by(id: assistant_id)
    return unless assistant&.leads_enabled?

    conversation = assistant.account.conversations.find_by(id: conversation_id)
    return unless conversation

    team = assistant.account.teams.find_by(id: assistant.config['lead_notification_team_id'])
    return unless team

    with_lock("captain:lead_notification:#{conversation.id}", 60.seconds) { deliver(assistant, conversation, team) }
  end

  private

  def deliver(assistant, conversation, team)
    conversation.reload
    return if conversation.additional_attributes['lead_notification_sent_at']
    return unless Captain::Leads::CaptureReceipt.valid?(assistant, conversation.contact)

    validate_delivery!(assistant.account, team)

    TeamNotifications::BusinessLeadMailer.with(account: assistant.account).lead_created(conversation, team).deliver_now
    conversation.with_lock do
      conversation.update!(additional_attributes: conversation.additional_attributes.merge('lead_notification_sent_at' => Time.current.iso8601))
    end
    assistant.account.increment_email_sent_count
  end

  def validate_delivery!(account, team)
    raise 'Configure SMTP before enabling lead notifications' unless ENV['SMTP_ADDRESS'].present? || Rails.env.development?
    raise 'Add a member to the lead notification team' unless team.team_members.exists?
    raise 'The account email limit has been reached' unless account.within_email_rate_limit?
  end
end
