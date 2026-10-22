require 'rails_helper'

RSpec.describe Captain::Knowledge::RefreshBriefsJob do
  let(:assistant) { create(:captain_assistant) }
  let(:brief) { assistant.create_knowledge_brief!(account: assistant.account, status: 'ready', generated_at: 4.hours.ago) }

  before { create(:captain_document, assistant: assistant, account: assistant.account, status: :available) }

  it 'drafts a new profile for a day-old agent once its knowledge changed' do
    brief

    described_class.perform_now

    expect(brief.reload.status).to eq('queued')
    expect(Captain::Knowledge::GenerateBriefJob).to have_been_enqueued.with(assistant.id, nil, pick_sources: true)
  end

  it 'waits while nothing changed since the last draft' do
    brief.update!(generated_at: 1.minute.from_now)
    travel 4.hours

    described_class.perform_now

    expect(Captain::Knowledge::GenerateBriefJob).not_to have_been_enqueued
  end

  it 'slows down as the agent settles' do
    assistant.update!(created_at: 3.days.ago)

    described_class.perform_now

    expect(brief.reload.status).to eq('ready')
    expect(Captain::Knowledge::GenerateBriefJob).not_to have_been_enqueued
  end

  it 'retries a failed draft after the interval' do
    brief.update!(status: 'failed', error_code: 'generation_failed', updated_at: 4.hours.ago)

    described_class.perform_now

    expect(brief.reload).to have_attributes(status: 'queued', error_code: nil)
  end
end
