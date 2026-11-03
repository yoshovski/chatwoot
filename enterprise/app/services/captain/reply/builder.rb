# Builds the plan of one reply from the model's draft: each policy shapes one aspect, always in this order.
class Captain::Reply::Builder
  POLICIES = [
    Captain::Reply::Policies::Greeting, Captain::Reply::Policies::Answer, Captain::Reply::Policies::Split,
    Captain::Reply::Policies::FollowUp, Captain::Reply::Policies::Suggestions, Captain::Reply::Policies::Cards,
    Captain::Reply::Policies::LeadForm, Captain::Reply::Policies::Confirmation, Captain::Reply::Policies::Channel
  ].freeze

  def self.build(context, draft)
    workspace = Captain::Reply::Workspace.new(context, draft)
    POLICIES.each { |policy| policy.new(workspace).apply }
    Captain::Reply::Plan.new(workspace.segments)
  end

  # Whether the run left nothing to say and no reason to say so (the chat job then hands the customer over).
  def self.empty_answer?(context, draft)
    workspace = Captain::Reply::Workspace.new(context, draft)
    Captain::Reply::Policies::Greeting.new(workspace).apply
    Captain::Reply::Policies::Answer.empty?(workspace)
  end
end
