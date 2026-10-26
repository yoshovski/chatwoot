# Email follow-up uses the signed intake and form without transferring the live chat.
class Captain::Leads::FollowupCaptureService < Captain::Leads::HandoffCaptureService
  PURPOSE = 'captain_business_followup'.freeze

  def pending_details = verified_payload&.slice('lead_type', 'summary', 'fields') || {}

  private

  def attribute_key = 'business_followup'

  def enabled?
    @assistant&.leads_enabled? && @conversation.account_id == @assistant.account_id
  end
end
