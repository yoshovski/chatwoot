# When the run asked for the business follow-up form, the form replaces the closing question (and the buttons). With
# nothing else to say, the form is the whole reply.
class Captain::Reply::Policies::LeadForm < Captain::Reply::Policies::Base
  def apply
    return unless context.followup_form_requested

    form = Captain::Reply::Segment.from_payload('form', Captain::Leads::FollowupFormService.new(assistant, conversation).payload)
    answer_left = workspace.question.nil? || workspace.remove_question!
    workspace.segments = answer_left ? [*workspace.segments, form] : [form]
  end
end
