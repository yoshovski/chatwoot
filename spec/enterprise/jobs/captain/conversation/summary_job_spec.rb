require 'rails_helper'

RSpec.describe Captain::Conversation::SummaryJob do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox).reload }

  it 'writes the summary with the handoff prompt' do
    note_service = instance_double(Captain::Conversation::HandoffNoteService, generate_summary: "Wants: A refund\nNext: Check the order")
    allow(Captain::Conversation::HandoffNoteService).to receive(:new).with(conversation: conversation).and_return(note_service)

    described_class.perform_now(conversation, 'resolved')

    expect(conversation.reload.additional_attributes['captain_summary'])
      .to include('status' => 'resolved', 'wants' => 'A refund', 'next_step' => 'Check the order')
  end
end
