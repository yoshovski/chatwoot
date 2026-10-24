class TeamNotifications::BusinessLeadMailer < ApplicationMailer
  append_view_path Rails.root.join('enterprise/app/views/mailers')

  # SMTP errors must reach the job so delivery can be retried rather than reported as successful.
  rescue_from(*ExceptionList::SMTP_EXCEPTIONS) { |error| raise error }

  def lead_created(conversation, team)
    @conversation = conversation
    @contact = conversation.contact
    @action_url = app_account_conversation_url(account_id: conversation.account_id, id: conversation.display_id)
    assistant = conversation.account.captain_assistants.find(@contact.additional_attributes.fetch('lead_assistant_id'))
    keys = %w[lead_type lead_summary lead_source] + assistant.lead_fields.map { |field| "lead_#{field['key']}" }
    @details = @contact.custom_attributes.slice(*keys)
    send_mail_with_liquid(to: team.team_members.includes(:user).map { |member| member.user.email },
                          reply_to: @contact.email, subject: "New business inquiry — #{conversation.inbox.name}")
  end

  private

  def liquid_locals
    super.merge(lead_name: @contact.name, lead_email: @contact.email,
                lead_details: @details.map { |key, value| [key.delete_prefix('lead_').humanize, value] })
  end
end
