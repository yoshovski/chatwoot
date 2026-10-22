require 'rails_helper'

RSpec.describe Captain::Assistant::DirectResponseService do
  let(:assistant) { create(:captain_assistant) }
  let(:service) { described_class.new(assistant: assistant, response_schema: Captain::ResponseSchema.for(suggested_replies: false)) }
  let(:route) { { 'intent' => 'faq_kb', 'queries' => ['payment configuration'] } }
  let(:context) { { state: {}, conversation_history: [{ role: 'user', content: 'how to set up Payment Configuration' }] } }
  let(:lookup) { instance_double(Captain::Tools::FaqLookupTool) }

  before { allow(Captain::Tools::FaqLookupTool).to receive(:new).with(assistant).and_return(lookup) }

  it 'hands the question to the action agent when the routed search finds nothing' do
    allow(lookup).to receive(:perform_queries).and_return(Captain::Tools::FaqLookupTool::NO_DIRECT_RESULTS)
    allow(Captain::Assistant::TieredLlmClient).to receive(:generate)

    expect(service.run(message: 'how to set up Payment Configuration', context: context, route: route)).to be_nil
    expect(Captain::Assistant::TieredLlmClient).not_to have_received(:generate)
  end
end
