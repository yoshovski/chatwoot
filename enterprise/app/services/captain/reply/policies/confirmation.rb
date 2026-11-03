# A confirm-mode action's Confirm/Cancel card comes last and replaces the suggestion buttons.
class Captain::Reply::Policies::Confirmation < Captain::Reply::Policies::Base
  def apply
    return if context.suppress_suggestions || context.action_confirmation.blank?

    payload = Captain::Tools::ActionConfirmation.card_payload(context.action_confirmation, assistant.account.locale)
    workspace.segments << Captain::Reply::Segment.from_payload('confirmation', payload)
  end
end
