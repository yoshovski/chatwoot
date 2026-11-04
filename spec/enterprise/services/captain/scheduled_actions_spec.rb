require 'rails_helper'

RSpec.describe Captain::ScheduledActions do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:conversation) { create(:conversation, account: account) }

  describe '.schedule!' do
    it 'stores a pending action and enqueues its job for due_at' do
      due_at = 2.hours.from_now

      expect do
        described_class.schedule!(conversation: conversation, assistant: assistant, kind: 'follow_up_message', at: due_at,
                                  payload: { 'template' => 'Still there?' })
      end.to have_enqueued_job(Captain::ScheduledActions::DispatchJob).at(a_value_within(1.second).of(due_at))

      expect(Captain::ScheduledAction.last).to have_attributes(status: 'pending', kind: 'follow_up_message', account_id: account.id,
                                                               cancel_on: Captain::ScheduledAction::CANCEL_REASONS)
    end

    it 'returns the pending action with the same dedupe key instead of a second one' do
      first = described_class.schedule!(conversation: conversation, assistant: assistant, kind: 'follow_up_message', at: 1.hour.from_now,
                                        dedupe_key: 'plan')
      second = described_class.schedule!(conversation: conversation, assistant: assistant, kind: 'follow_up_message', at: 2.hours.from_now,
                                         dedupe_key: 'plan')

      expect(second).to eq(first)
      expect(Captain::ScheduledAction.count).to eq(1)
    end

    it 'allows at most three pending actions per conversation' do
      3.times { |index| create(:captain_scheduled_action, conversation: conversation, assistant: assistant, dedupe_key: index.to_s) }

      expect do
        described_class.schedule!(conversation: conversation, assistant: assistant, kind: 'follow_up_message', at: 1.hour.from_now)
      end.to raise_error(ActiveRecord::RecordInvalid, /at most 3/)
    end

    it 'rejects a payload over 10 KB' do
      expect do
        described_class.schedule!(conversation: conversation, assistant: assistant, kind: 'follow_up_message', at: 1.hour.from_now,
                                  payload: { 'instructions' => 'a' * 11.kilobytes })
      end.to raise_error(ActiveRecord::RecordInvalid, /Payload is too large/)
    end
  end

  describe '.cancel!' do
    it 'cancels only pending actions of that conversation that stop on the reason' do
      stops = create(:captain_scheduled_action, conversation: conversation, assistant: assistant)
      keeps = create(:captain_scheduled_action, conversation: conversation, assistant: assistant, cancel_on: %w[resolved])
      other = create(:captain_scheduled_action, assistant: assistant)
      done = create(:captain_scheduled_action, conversation: conversation, assistant: assistant, status: :done)

      expect(described_class.cancel!(conversation: conversation, reason: 'visitor_message')).to eq(1)

      expect(stops.reload).to have_attributes(status: 'cancelled', cancel_reason: 'visitor_message')
      expect([keeps, other].map { |action| action.reload.status }).to eq(%w[pending pending])
      expect(done.reload.status).to eq('done')
    end
  end
end
