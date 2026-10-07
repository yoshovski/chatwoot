# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Llm::Models do
  describe '.providers' do
    it 'loads provider metadata from the config' do
      expect(described_class.providers).to include(
        'openai' => include('display_name' => 'OpenAI')
      )
    end
  end

  describe '.features' do
    it 'keeps every feature default in the allowed model list' do
      described_class.features.each do |feature_key, config|
        expect(config['models']).to include(config['default']), "#{feature_key} default model must be allowed"
      end
    end

    it 'references existing models from every feature' do
      described_class.features.each do |feature_key, config|
        missing_models = config['models'].reject { |model_name| described_class.models.key?(model_name) }

        expect(missing_models).to be_empty, "#{feature_key} references missing models: #{missing_models.join(', ')}"
      end
    end

    it 'routes each FAQ operation independently' do
      expect(described_class.default_model_for('document_faq_generation')).to eq('gpt-4.1-mini')
      expect(described_class.default_model_for('conversation_faq_generation')).to eq('gpt-5.2')
      expect(described_class.default_model_for('conversation_faq_matching')).to eq('gpt-4.1-mini')
    end

    it 'offers only supported OpenAI models for conversation completion' do
      expect(described_class.models_for('conversation_completion')).to eq(
        %w[gpt-4.1-mini gpt-5-mini gpt-4.1 gpt-5.1 gpt-5.2]
      )
    end

    it 'includes gpt-6-luna in assistant and copilot models' do
      expect(described_class.models_for('assistant')).to include('gpt-6-luna')
      expect(described_class.models_for('copilot')).to include('gpt-6-luna')
      expect(described_class.model_config('gpt-6-luna')).to include(
        'provider' => 'openai',
        'display_name' => 'GPT-6 Luna',
        'credit_multiplier' => 1
      )
    end
  end

  describe '.models' do
    it 'references existing providers from every model' do
      missing_providers = described_class.models.filter_map do |model_name, config|
        provider = config['provider']
        next if described_class.providers.key?(provider)

        "#{model_name}: #{provider}"
      end

      expect(missing_providers).to be_empty
    end

    it 'registers every selectable model in the RubyLLM model registry' do
      registry_ids = JSON.parse(Rails.root.join('config/llm_models.json').read).pluck('id')
      unregistered_models = described_class.models.filter_map do |model_name, config|
        model_name unless config['coming_soon'] || registry_ids.include?(model_name)
      end

      expect(unregistered_models).to be_empty, "add to config/llm_models.json: #{unregistered_models.join(', ')}"
    end
  end

  describe '.feature_config' do
    it 'returns model metadata for a feature' do
      config = described_class.feature_config('editor')

      expect(config[:default]).to eq('gpt-4.1-mini')
      expect(config[:models].first).to include(
        id: 'gpt-4.1-mini',
        display_name: 'GPT-4.1 Mini',
        provider: 'openai',
        credit_multiplier: 1
      )
    end
  end
end
