require 'rails_helper'

RSpec.describe Captain::Llm::PdfProcessingService do
  let(:document) { create(:captain_document) }

  describe '#process' do
    it 'queues Dify ingestion without constructing an OpenAI client or marking the document ready' do
      expect(OpenAI::Client).not_to receive(:new)

      expect { described_class.new(document).process }
        .to have_enqueued_job(Captain::Dify::SyncDocumentJob).with(document.id)
      expect(document.reload).to be_in_progress
    end

    it 'sends legacy PDFs to Dify even when an old OpenAI file ID is present' do
      document.update!(openai_file_id: 'old-file-id')

      expect { described_class.new(document).process }
        .to have_enqueued_job(Captain::Dify::SyncDocumentJob).with(document.id)
    end
  end
end
