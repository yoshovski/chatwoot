require 'rails_helper'

RSpec.describe Captain::Dify::SyncFaqJob do
  let(:response) { create(:captain_assistant_response) }
  let(:service) { instance_double(Captain::Dify::FaqSyncService) }

  it 'retries a pending Dify index' do
    allow(Captain::Dify::FaqSyncService).to receive(:new).with(response).and_return(service)
    allow(service).to receive(:perform).and_raise(Captain::Dify::FaqSyncService::IndexingPending, 'Dify FAQ document is indexing')
    clear_enqueued_jobs

    expect { described_class.perform_now(response.id) }.to have_enqueued_job(described_class).with(response.id)
  end

  it 'logs an exhausted failure by FAQ ID and status without FAQ wording or credentials' do
    allow(Captain::Dify::FaqSyncService).to receive(:new).and_return(service)
    allow(service).to receive(:perform).and_raise(Dify::KnowledgeClient::Error.new('Dify request failed', status: 503))
    allow(Rails.logger).to receive(:error)
    job = described_class.new(response.id)
    15.times { job.perform_now }

    message = "Dify FAQ sync failed response_id=#{response.id} error=Dify::KnowledgeClient::Error status=503"
    expect(Rails.logger).to have_received(:error).with(message)
  end
end
