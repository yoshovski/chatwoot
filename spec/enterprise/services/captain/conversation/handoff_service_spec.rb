require 'rails_helper'

RSpec.describe Captain::Conversation::HandoffService do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, status: :pending).reload }
  let(:service) { described_class.new(conversation: conversation, assistant: assistant) }

  before do
    create(:captain_inbox, captain_assistant: assistant, inbox: inbox)
    allow(Captain::Conversation::HandoffNoteService).to receive(:new).and_call_original
    allow_any_instance_of(Captain::Conversation::HandoffNoteService) # rubocop:disable RSpec/AnyInstance
      .to receive(:generate_summary).and_return("Wants: A refund\nNext: Check the order")
  end

  it 'stores the summary and posts it as a private note by default' do
    service.apply_extras!

    expect(conversation.reload.additional_attributes['captain_summary']).to include('status' => 'handed_off', 'wants' => 'A refund')
    expect(conversation.messages.where(private: true).last.content).to include('Wants: A refund')
  end

  it 'stores the summary without a private note when the setting is off' do
    assistant.update!(config: assistant.config.merge('summary_private_note' => false))

    expect(service.apply_extras!).to be_nil

    expect(conversation.reload.additional_attributes['captain_summary']).to include('wants' => 'A refund', 'next_step' => 'Check the order')
    expect(conversation.messages.where(private: true)).to be_empty
  end
end
