require 'rails_helper'

RSpec.describe Captain::Documents::ResponseBuilderJob, type: :job do
  let(:assistant) { create(:captain_assistant) }
  let(:document) { create(:captain_document, assistant: assistant) }
  let(:faq_generator) { instance_double(Captain::Llm::FaqGeneratorService) }
  let(:faqs) do
    [
      { 'question' => 'What is Ruby?', 'answer' => 'A programming language' },
      { 'question' => 'What is Rails?', 'answer' => 'A web framework' }
    ]
  end

  before do
    allow(Captain::Llm::FaqGeneratorService).to receive(:new).with(document: document).and_return(faq_generator)
    allow(faq_generator).to receive(:generate).and_return(faqs)
  end

  describe '#perform' do
    context 'when processing a document' do
      it 'deletes previous responses' do
        existing_response = create(:captain_assistant_response, documentable: document)

        described_class.new.perform(document)

        expect { existing_response.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'creates new responses for each FAQ' do
        expect do
          described_class.new.perform(document)
        end.to change(Captain::AssistantResponse, :count).by(2)

        responses = document.responses.reload
        expect(responses.count).to eq(2)

        first_response = responses.first
        expect(first_response.question).to eq('What is Ruby?')
        expect(first_response.answer).to eq('A programming language')
        expect(first_response.assistant).to eq(assistant)
        expect(first_response.documentable).to eq(document)
      end
    end

    context 'with different locales' do
      let(:spanish_account) { create(:account, locale: 'pt') }
      let(:spanish_assistant) { create(:captain_assistant, account: spanish_account) }
      let(:spanish_document) { create(:captain_document, assistant: spanish_assistant, account: spanish_account) }
      let(:spanish_faq_generator) { instance_double(Captain::Llm::FaqGeneratorService) }

      before do
        allow(Captain::Llm::FaqGeneratorService).to receive(:new).with(document: spanish_document).and_return(spanish_faq_generator)
        allow(spanish_faq_generator).to receive(:generate).and_return(faqs)
      end

      it 'passes the correct document to FAQ generator' do
        described_class.new.perform(spanish_document)

        expect(Captain::Llm::FaqGeneratorService).to have_received(:new).with(document: spanish_document)
      end
    end

    context 'when processing a PDF document' do
      let(:pdf_document) do
        doc = create(:captain_document, assistant: assistant)
        allow(doc).to receive(:pdf_document?).and_return(true)
        allow(doc).to receive(:openai_file_id).and_return('file-123')
        doc
      end

      it 'does not generate FAQs even when a legacy OpenAI file ID exists' do
        expect(Captain::Llm::PaginatedFaqGeneratorService).not_to receive(:new)

        expect { described_class.new.perform(pdf_document) }.not_to change(Captain::AssistantResponse, :count)
      end
    end

    context 'when metadata page_faqs are present' do
      let(:page_faqs) do
        [
          { 'question' => 'How to return?', 'answer' => 'Return within 30 days.' },
          { 'question' => 'Shipping cost?', 'answer' => 'Free shipping.' }
        ]
      end

      before do
        document.update!(
          status: :available,
          metadata: { 'page_faqs' => page_faqs, 'dify_indexing_status' => 'completed' }
        )
      end

      it 'imports pairs verbatim with page_import origin and does not call generator in Dify mode' do
        allow(document.account).to receive(:dify_knowledge_enabled?).and_return(true)

        expect(Captain::Llm::FaqGeneratorService).not_to receive(:new)

        expect do
          described_class.new.perform(document)
        end.to change(Captain::AssistantResponse, :count).by(2)

        responses = document.responses.reload
        expect(responses.map(&:origin)).to all(eq('page_import'))
        expect(responses.map(&:question)).to contain_exactly('How to return?', 'Shipping cost?')
        expect(responses.map(&:answer)).to contain_exactly('Return within 30 days.', 'Free shipping.')
      end

      it 'keeps existing generated FAQs when importing page FAQs' do
        allow(document.account).to receive(:dify_knowledge_enabled?).and_return(true)
        existing_ai = create(:captain_assistant_response, documentable: document, origin: 'ai_generated', question: 'Existing AI?')

        described_class.new.perform(document)

        expect(existing_ai.reload).to be_present
        expect(document.responses.reload.count).to eq(3)
      end
    end

    context 'when force_ai is true' do
      before do
        document.update!(status: :available, dify_indexing_status: 'completed')
      end

      it 'keeps imported and edited FAQs while regenerating unedited AI FAQs' do
        allow(document.account).to receive(:dify_knowledge_enabled?).and_return(true)

        imported = create(:captain_assistant_response, documentable: document, origin: 'page_import', question: 'Imported Q', edited: false)
        edited_ai = create(:captain_assistant_response, documentable: document, origin: 'ai_generated', question: 'Edited Q', edited: true)
        unedited_ai = create(:captain_assistant_response, documentable: document, origin: 'ai_generated', question: 'Unedited Q', edited: false)
        legacy = create(:captain_assistant_response, documentable: document, origin: nil, question: 'Legacy Q', edited: false)

        described_class.new.perform(document, force_ai: true)

        expect(imported.reload).to be_present
        expect(edited_ai.reload).to be_present
        expect { unedited_ai.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { legacy.reload }.to raise_error(ActiveRecord::RecordNotFound)

        new_responses = document.responses.where(origin: 'ai_generated', edited: false)
        expect(new_responses.count).to eq(2)
      end
    end
  end
end
