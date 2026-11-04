require 'rails_helper'

RSpec.describe Captain::ScheduledActions::SweepJob do
  it 'dispatches pending actions whose job was lost' do
    lost = create(:captain_scheduled_action, due_at: 5.minutes.ago)
    create(:captain_scheduled_action, due_at: 30.seconds.ago)
    create(:captain_scheduled_action, due_at: 1.hour.from_now)

    expect { described_class.perform_now }.to have_enqueued_job(Captain::ScheduledActions::DispatchJob).with(lost.id).exactly(:once)
  end

  it 'deletes finished actions older than 30 days' do
    old = create(:captain_scheduled_action, status: :done, updated_at: 31.days.ago)
    recent = create(:captain_scheduled_action, status: :cancelled, updated_at: 1.day.ago)
    waiting = create(:captain_scheduled_action, updated_at: 31.days.ago, due_at: 1.hour.from_now)

    described_class.perform_now

    expect(Captain::ScheduledAction.where(id: [old, recent, waiting].map(&:id)).pluck(:id)).to contain_exactly(recent.id, waiting.id)
  end

  it 'runs from the scheduled items job' do
    expect { TriggerScheduledItemsJob.perform_now }.to have_enqueued_job(described_class)
  end
end
