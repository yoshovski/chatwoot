require 'rails_helper'

RSpec.describe Captain::Knowledge::GenerateBriefJob do
  let(:assistant) { create(:captain_assistant, config: { 'knowledge_brief_enabled' => true }) }
  let(:brief) { assistant.create_knowledge_brief!(account: assistant.account, status: 'ready', published: { 'document_ids' => [0] }) }

  it 'pauses the profile instead of failing when every published source is gone' do
    allow(Captain::Knowledge::BriefGenerator).to receive(:new).and_call_original
    described_class.perform_now(assistant.id) if brief

    expect(brief.reload).to have_attributes(status: 'idle', error_code: nil)
    expect(Captain::Knowledge::BriefGenerator).not_to have_received(:new)
  end
end
