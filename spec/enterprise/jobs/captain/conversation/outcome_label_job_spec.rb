# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Captain::Conversation::OutcomeLabelJob, type: :job do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:assistant) { create(:captain_assistant, account: account, config: { 'outcome_labels' => true }) }
  let(:conversation) { create(:conversation, inbox: inbox, account: account, status: :resolved) }
  let(:classifier) { instance_double(Captain::Llm::OutcomeClassifierService) }

  before do
    allow(account).to receive(:feature_enabled?).and_return(false)
    allow(account).to receive(:feature_enabled?).with('captain_integration_v2').and_return(true)
    allow(Captain::Llm::OutcomeClassifierService).to receive(:new).and_return(classifier)
    create(:message, conversation: conversation, content: 'Can I buy this?', message_type: :incoming)
    create(:message, conversation: conversation, content: 'Yes, here is the link.', message_type: :outgoing)
  end

  describe '#perform' do
    it 'picks a valid outcome label' do
      allow(classifier).to receive(:classify).and_return('bot-resolved')

      described_class.perform_now(conversation, assistant)

      expect(conversation.reload.label_list).to include('bot-resolved')
    end

    it 'replaces a stale outcome label and preserves unrelated labels' do
      conversation.update_labels(%w[vip purchase-intent])
      allow(classifier).to receive(:classify).and_return('bot-resolved')

      described_class.perform_now(conversation, assistant)

      conversation.reload
      expect(conversation.label_list).to include('vip', 'bot-resolved')
      expect(conversation.label_list).not_to include('purchase-intent')
    end

    it 'removes needs-human on resolution' do
      conversation.update_labels(%w[needs-human])
      allow(classifier).to receive(:classify).and_return('handed-to-human')

      described_class.perform_now(conversation, assistant)

      conversation.reload
      expect(conversation.label_list).to include('handed-to-human')
      expect(conversation.label_list).not_to include('needs-human')
    end

    it 'ignores an invalid model answer and leaves labels unchanged' do
      conversation.update_labels(%w[purchase-intent])
      allow(classifier).to receive(:classify).and_return(nil)

      described_class.perform_now(conversation, assistant)

      conversation.reload
      expect(conversation.label_list).to eq(['purchase-intent'])
    end

    it 'skips when account has no captain responses left' do
      allow(account).to receive(:usage_limits).and_return(
        { captain: { responses: { current_available: 0 } } }
      )
      expect(Captain::Llm::OutcomeClassifierService).not_to receive(:new)

      described_class.perform_now(conversation, assistant)
    end
  end
end
