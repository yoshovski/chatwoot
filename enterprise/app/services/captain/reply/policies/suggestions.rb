# Suggestion buttons on the closing bubble, or on the answer when there is none. None when the run ends in a handoff,
# asks for the follow-up form or waits for an action's Confirm/Cancel card.
class Captain::Reply::Policies::Suggestions < Captain::Reply::Policies::Base
  def apply
    items = suggestions
    return if items.blank?

    # submit_value: a click sends the item's value (the full question), while the button shows its short title.
    workspace.buttons = { items: items, submit_value: true }
    index = workspace.closing ? -1 : workspace.answer_index
    workspace.segments[index] = workspace.with_buttons(workspace.segments[index])
  end

  private

  def suggestions
    Captain::Conversation::SuggestionFinalizer.new(
      assistant: assistant, response: draft.raw, run_result: run_result, customer_message: context.customer_message,
      suppress_suggestions: suppressed?, has_closing_question: workspace.has_closing_question
    ).perform
  end

  def suppressed?
    context.suppress_suggestions || context.followup_form_requested || context.action_confirmation.present?
  end
end
