# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Captain::Conversation::CheckInJob, type: :job do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:conversation) { create(:conversation, account: account, status: :pending) }

  it 'drains jobs queued before widget attention without sending anything' do
    expect { described_class.perform_now(conversation.id, assistant.id) }.not_to(change { conversation.messages.count })
  end
end
