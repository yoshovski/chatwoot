require 'rails_helper'

RSpec.describe Captain::Dify::SyncDocumentJob do
  it 'records missing Dify configuration as a failure without making an OpenAI call' do
    document = create(:captain_document)
    expect(OpenAI::Client).not_to receive(:new)

    described_class.perform_now(document.id)

    expect(document.reload).to be_sync_failed
    expect(document.last_sync_error_code).to eq('dify_not_configured')
    expect(document).to be_in_progress
  end
end
