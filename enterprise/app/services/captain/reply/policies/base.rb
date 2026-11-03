# A policy shapes one aspect of the reply on the workspace; Captain::Reply::Builder runs them in a fixed order.
class Captain::Reply::Policies::Base
  attr_reader :workspace

  delegate :context, :draft, :assistant, :conversation, :run_result, to: :workspace

  def initialize(workspace)
    @workspace = workspace
  end
end
