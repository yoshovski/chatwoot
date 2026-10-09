require 'rails_helper'

RSpec.describe Captain::Tools::FaqLookupTool, type: :model do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:tool) { described_class.new(assistant) }
  let(:tool_context) { Struct.new(:state).new({}) }

  before do
    # Create installation config for OpenAI API key to avoid errors
    create(:installation_config, name: 'CAPTAIN_OPEN_AI_API_KEY', value: 'test-key')

    # Mock embedding service to avoid actual API calls
    embedding_service = instance_double(Captain::Llm::EmbeddingService)
    allow(Captain::Llm::EmbeddingService).to receive(:new).and_return(embedding_service)
    allow(embedding_service).to receive(:get_embedding).and_return(Array.new(1536, 0.1))
  end

  describe '#description' do
    it 'returns the correct description' do
      expect(tool.description).to include('specifications, box contents, compatibility, model differences')
    end
  end

  describe '#parameters' do
    it 'returns the correct parameters' do
      expect(tool.parameters).to have_key(:query)
      expect(tool.parameters[:query].name).to eq(:query)
      expect(tool.parameters[:query].type).to eq('string')
      expect(tool.parameters[:query].description).to start_with('A few key words from the latest customer question')
    end
  end

  describe '#perform' do
    context 'when FAQs exist' do
      let(:document) { create(:captain_document, assistant: assistant) }
      let!(:response1) do
        create(:captain_assistant_response,
               assistant: assistant,
               question: 'How to reset password?',
               answer: 'Click on forgot password link',
               documentable: document,
               status: 'approved')
      end
      let!(:response2) do
        create(:captain_assistant_response,
               assistant: assistant,
               question: 'How to change email?',
               answer: 'Go to settings and update email',
               documentable: document,
               status: 'approved')
      end

      before do
        allow(Resolv).to receive(:getaddresses).and_return(['93.184.216.34'])

        # Mock nearest_neighbors to return our test responses
        allow(Captain::AssistantResponse).to receive(:nearest_neighbors) do
          (Captain::AssistantResponse.current_scope || Captain::AssistantResponse.all).where(id: [response1.id, response2.id])
        end
      end

      it 'searches FAQs and returns formatted responses' do
        result = tool.perform(tool_context, query: 'password reset')

        expect(result).to include('Question: How to reset password?')
        expect(result).to include('Answer: Click on forgot password link')
        expect(result).to include('Question: How to change email?')
        expect(result).to include('Answer: Go to settings and update email')
        expect(result).to include('Source index: 1', 'Source index: 2')
      end

      it 'excludes FAQs when their parent document is paused, and brings them back when resumed' do
        document.update!(enabled: false)
        result = tool.perform(tool_context, query: 'password reset')
        expect(result).to eq('No relevant FAQs found for: password reset')

        document.update!(enabled: true)
        resumed_result = tool.perform(tool_context, query: 'password reset')
        expect(resumed_result).to include('Question: How to reset password?')
      end

      it 'excludes an FAQ when the FAQ itself is paused, and brings it back when resumed' do
        response1.update!(enabled: false)
        result = tool.perform(tool_context, query: 'password reset')
        expect(result).not_to include('Question: How to reset password?')
        expect(result).to include('Question: How to change email?')

        response1.update!(enabled: true)
        resumed_result = tool.perform(tool_context, query: 'password reset')
        expect(resumed_result).to include('Question: How to reset password?')
      end

      it 'records each result as a source with its question and answer' do
        tool.perform(tool_context, query: 'password reset')

        expect(tool_context.state[Captain::Assistant::CITATION_SOURCES_STATE_KEY]).to eq(1 => "faq:#{response1.id}", 2 => "faq:#{response2.id}")
        expect(tool_context.state[Captain::Assistant::CITATION_DETAILS_STATE_KEY]["faq:#{response1.id}"]).to include(
          kind: 'faq', title: 'How to reset password?', excerpt: 'Click on forgot password link', faq_id: response1.id
        )
      end

      it 'never records attachments, storage links or credentials as source links' do
        assistant.update!(config: assistant.config.merge('feature_citation' => true))
        reference = "faq:#{response1.id}"
        document.pdf_file.attach(
          io: StringIO.new('PDF content'),
          filename: 'private-file.pdf',
          content_type: 'application/pdf'
        )

        ['s3://private-bucket/password', 'https://storage.example.com/private-file.pdf?token=secret',
         'https://user:pass@help.example.com/password'].each do |link|
          document.pdf_file.detach if link.start_with?('s3:')
          document.update!(external_link: link)
          tool_context.state.clear

          result = tool.perform(tool_context, query: 'private document')

          expect(result).not_to include(link)
          expect(tool_context.state[Captain::Assistant::CITATION_DETAILS_STATE_KEY][reference]).not_to have_key(:url)
          expect(assistant.customer_visible_citation_urls(tool_context.state[Captain::Assistant::CITATION_SOURCES_STATE_KEY])).to be_empty
        end
      end

      it 'keeps stable source indexes across lookups and records customer-visible links' do
        document.update!(external_link: 'https://help.example.com/password')

        result = tool.perform(tool_context, query: 'password')
        repeated_result = tool.perform(tool_context, query: 'password again')

        expect(result).to include('Source index: 1', 'Source index: 2')
        expect(repeated_result).to include('Source index: 1')
        expect(result).not_to include('https://help.example.com/password')
        expect(tool_context.state[Captain::Assistant::CITATION_SOURCES_STATE_KEY]).to eq(1 => "faq:#{response1.id}", 2 => "faq:#{response2.id}")
        expect(tool_context.state[Captain::Assistant::CITATION_DETAILS_STATE_KEY]["faq:#{response1.id}"][:url]).to eq('https://help.example.com/password')
      end

      it 'logs tool usage for search' do
        expect(tool).to receive(:log_tool_usage).with('searching', { query: 'password reset' })
        expect(tool).to receive(:log_tool_usage).with('found_results', { query: 'password reset', count: 2 })

        tool.perform(tool_context, query: 'password reset')
      end

      it 'records retrieved faq ids and document ids into Chatwoot metadata' do
        tool.perform(tool_context, query: 'password reset')

        user = create(:user, account: account)
        user_faq = create(:captain_assistant_response, assistant: assistant, documentable: user, status: :approved)
        allow(Captain::AssistantResponse).to receive(:nearest_neighbors).and_return(
          Captain::AssistantResponse.where(id: user_faq.id)
        )
        tool.perform(tool_context, query: 'user faq')

        expect(tool_context.state.dig(:cw_metadata, :faq_ids)).to contain_exactly(response1.id, response2.id, user_faq.id)
        expect(tool_context.state.dig(:cw_metadata, :used_faq_ids)).to contain_exactly(user_faq.id)
        expect(tool_context.state.dig(:cw_metadata, :document_ids)).to contain_exactly(document.id)
      end

      it 'accumulates unique ids across multiple calls' do
        tool.perform(tool_context, query: 'password reset')
        tool.perform(tool_context, query: 'password reset again')

        expect(tool_context.state.dig(:cw_metadata, :faq_ids)).to contain_exactly(response1.id, response2.id)
        expect(tool_context.state.dig(:cw_metadata, :document_ids)).to contain_exactly(document.id)
      end
    end

    context 'when no FAQs found' do
      before do
        # Return empty result set
        allow(Captain::AssistantResponse).to receive(:nearest_neighbors).and_return(Captain::AssistantResponse.none)
      end

      it 'returns no results message' do
        result = tool.perform(tool_context, query: 'nonexistent topic')
        expect(result).to eq('No relevant FAQs found for: nonexistent topic')
      end

      it 'logs tool usage for no results' do
        expect(tool).to receive(:log_tool_usage).with('searching', { query: 'nonexistent topic' })
        expect(tool).to receive(:log_tool_usage).with('no_results', { query: 'nonexistent topic' })

        tool.perform(tool_context, query: 'nonexistent topic')
      end

      it 'leaves shared state untouched' do
        tool.perform(tool_context, query: 'nonexistent topic')

        expect(tool_context.state).to eq({})
      end

      it 'drops the business name from the search' do
        assistant.update!(config: assistant.config.merge('product_name' => 'Acme'))

        expect(tool.perform(tool_context, query: "Acme's return policy")).to eq('No relevant FAQs found for: return policy')
        expect(tool.perform(tool_context, query: 'Acme')).to eq('No relevant FAQs found for: Acme')
      end
    end

    context 'with blank query' do
      it 'handles empty query' do
        # Return empty result set
        allow(Captain::AssistantResponse).to receive(:nearest_neighbors).and_return(Captain::AssistantResponse.none)

        result = tool.perform(tool_context, query: '')
        expect(result).to eq('No relevant FAQs found for: ')
      end
    end
  end

  describe '#active?' do
    it 'returns true for public tools' do
      expect(tool.active?).to be true
    end
  end
end
