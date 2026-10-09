require 'rails_helper'

RSpec.describe Captain::Llm::SystemPromptsService do
  describe '.copilot_response_generator' do
    before { GlobalConfig.clear_cache }

    after { GlobalConfig.clear_cache }

    it 'introduces the copilot with the configured AI agent product name' do
      create(:installation_config, name: 'CAPTAIN_BRAND_NAME', value: 'Luna')

      expect(described_class.copilot_response_generator('Acme', [])).to include('You are Luna, a helpful and friendly copilot assistant')
    end

    it 'defaults to Tony' do
      expect(described_class.copilot_response_generator('Acme', [])).to include('You are Tony, a helpful and friendly copilot assistant')
    end
  end
end
