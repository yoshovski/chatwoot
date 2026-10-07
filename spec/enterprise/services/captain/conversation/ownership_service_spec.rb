# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Captain::Conversation::OwnershipService do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account, config: { 'continue_while_waiting' => true }) }
  let(:inbox) { create(:inbox, account: account) }
  let(:user) { create(:user, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, status: :pending) }
  let(:service) { described_class.new(conversation: conversation, assistant: assistant) }

  before do
    create(:captain_inbox, captain_assistant: assistant, inbox: inbox)
  end

  describe '#may_reply?' do
    context 'when conversation is pending' do
      it 'returns true' do
        expect(service.may_reply?).to be true
      end
    end

    context 'when conversation is open' do
      before { conversation.update!(status: :open) }

      it 'returns true when continue_while_waiting is enabled and not taken over' do
        expect(service.may_reply?).to be true
      end

      it 'returns false when continue_while_waiting is disabled' do
        assistant.update!(config: { 'continue_while_waiting' => false })
        expect(service.may_reply?).to be false
      end

      it 'returns false when conversation has human-active label' do
        conversation.update_labels(['human-active'])
        expect(service.may_reply?).to be false
      end

      it 'returns false when a human public reply exists' do
        create(:message, account: account, inbox: inbox, conversation: conversation,
                         message_type: :outgoing, private: false, sender: user, created_at: Time.current)
        expect(service.may_reply?).to be false
      end

      it 'returns true when only private notes exist' do
        create(:message, account: account, inbox: inbox, conversation: conversation,
                         message_type: :outgoing, private: true, sender: user, created_at: Time.current)
        expect(service.may_reply?).to be true
      end
    end

    context 'when conversation is resolved or snoozed' do
      it 'returns false when resolved' do
        conversation.update!(status: :resolved)
        expect(service.may_reply?).to be false
      end

      it 'returns false when snoozed' do
        conversation.update!(status: :snoozed)
        expect(service.may_reply?).to be false
      end
    end
  end

  describe '#prompt_instruction' do
    it 'returns waiting instruction when waiting' do
      conversation.update!(status: :open)
      expect(service.prompt_instruction).to eq(described_class::WAITING_INSTRUCTION)
    end

    it 'returns returned to ai instruction when returned to ai flag is set' do
      conversation.update!(status: :pending, custom_attributes: { 'captain_returned_to_ai' => true })
      expect(service.prompt_instruction).to eq(described_class::RETURNED_TO_AI_INSTRUCTION)
    end

    it 'returns nil when neither waiting nor returned to ai' do
      expect(service.prompt_instruction).to be_nil
    end
  end

  describe '#record_human_takeover!' do
    it 'adds human-active label when open and continue_while_waiting is enabled' do
      conversation.update!(status: :open)
      service.record_human_takeover!
      expect(conversation.label_list).to include('human-active')
    end

    it 'does not add label when conversation is pending' do
      service.record_human_takeover!
      expect(conversation.label_list).not_to include('human-active')
    end

    it 'does not add label when continue_while_waiting is disabled' do
      conversation.update!(status: :open)
      assistant.update!(config: { 'continue_while_waiting' => false })
      service.record_human_takeover!
      expect(conversation.label_list).not_to include('human-active')
    end
  end

  describe '#take_over!' do
    it 'opens the conversation, assigns it to the agent and stops Captain from answering' do
      conversation.update!(ai_assignee: assistant)

      service.take_over!(user)

      expect(conversation.reload).to have_attributes(status: 'open', assignee: user, ai_assignee: nil)
      expect(conversation.label_list).to include('human-active')
      expect(service.may_reply?).to be false
    end

    it 'takes over an open conversation that Captain keeps answering while assigned to another agent' do
      other_agent = create(:user, account: account)
      conversation.update!(status: :open, assignee: other_agent)
      expect(conversation.captain_waiting_assistant).to eq(assistant)

      service.take_over!(user)

      expect(conversation.reload.assignee).to eq(user)
      expect(conversation.captain_waiting_assistant).to be_nil
    end
  end

  describe '#handle_returned_to_ai!' do
    before do
      conversation.update_labels(['human-active'])
      allow(Redis::Alfred).to receive(:delete)
    end

    it 'removes human-active label and sets returned_to_ai flags' do
      service.handle_returned_to_ai!
      expect(conversation.label_list).not_to include('human-active')
      expect(conversation.custom_attributes['captain_returned_to_ai']).to be true
      expect(conversation.custom_attributes['captain_returned_to_ai_at']).to be_present
    end

    it 'lets the next handoff offer the contact form again' do
      service.handle_returned_to_ai!

      expect(Redis::Alfred).to have_received(:delete).with("captain:contact_form:#{conversation.id}:email_name")
    end
  end

  describe '#handle_resolved!' do
    before do
      conversation.update_labels(['human-active'])
      conversation.update!(custom_attributes: { 'captain_returned_to_ai' => true, 'captain_returned_to_ai_at' => Time.current.iso8601 })
      allow(Redis::Alfred).to receive(:delete)
    end

    it 'removes human-active label and clears returned_to_ai attributes' do
      service.handle_resolved!
      expect(conversation.label_list).not_to include('human-active')
      expect(conversation.custom_attributes['captain_returned_to_ai']).to be_nil
      expect(conversation.custom_attributes['captain_returned_to_ai_at']).to be_nil
    end

    it 'lets the next handoff offer the contact form again' do
      service.handle_resolved!

      expect(Redis::Alfred).to have_received(:delete).with("captain:contact_form:#{conversation.id}:email_name")
    end
  end

  describe '#clear_returned_to_ai_flag!' do
    before do
      conversation.update!(custom_attributes: {
                             'captain_returned_to_ai' => true,
                             'captain_returned_to_ai_at' => Time.current.iso8601
                           })
    end

    it 'clears captain_returned_to_ai flag but preserves captain_returned_to_ai_at' do
      service.clear_returned_to_ai_flag!
      expect(conversation.custom_attributes['captain_returned_to_ai']).to be_nil
      expect(conversation.custom_attributes['captain_returned_to_ai_at']).to be_present
    end
  end
end
