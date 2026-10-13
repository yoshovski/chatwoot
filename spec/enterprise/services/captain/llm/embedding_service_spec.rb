require 'rails_helper'

RSpec.describe Captain::Llm::EmbeddingService, type: :service do
  def configure_embedding_model(value)
    InstallationConfig.find_or_initialize_by(name: 'CAPTAIN_EMBEDDING_MODEL').tap do |config|
      config.value = value
      config.locked = false
      config.save!
    end
  end

  describe '.embedding_model' do
    it 'uses the installation embedding model when configured' do
      configure_embedding_model('custom-embedding-model')

      expect(described_class.embedding_model).to eq('custom-embedding-model')
    end

    it 'falls back to the default embedding model when the installation value is blank' do
      configure_embedding_model('')

      expect(described_class.embedding_model).to eq(LlmConstants::DEFAULT_EMBEDDING_MODEL)
    end
  end

  describe '#get_embedding' do
    let(:account) { create(:account) }
    let(:embedding_response) { double('embedding_response', vectors: [0.1, 0.2]) } # rubocop:disable RSpec/VerifiedDoubles

    it 'sends the installation embedding model to RubyLLM' do
      configure_embedding_model('custom-embedding-model')

      provider = instance_double(RubyLLM::Providers::OpenAI)
      connection = instance_double(RubyLLM::Connection, connection: Faraday.new)
      model = instance_double(RubyLLM::Model::Info, id: 'custom-embedding-model')
      allow(provider).to receive(:connection).and_return(connection)
      expect(RubyLLM::Models).to receive(:resolve).with('custom-embedding-model', config: RubyLLM.config).and_return([model, provider])
      expect(provider).to receive(:embed).with('search text', model: 'custom-embedding-model', dimensions: nil).and_return(embedding_response)

      expect(described_class.new(account_id: account.id).get_embedding('search text')).to eq([0.1, 0.2])
    end
  end
end
