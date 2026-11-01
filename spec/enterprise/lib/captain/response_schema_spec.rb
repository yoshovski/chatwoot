require 'rails_helper'

RSpec.describe Captain::ResponseSchema do
  context 'with the AI welcome of a first reply' do
    let(:schema) { described_class.for(welcome: true, suggested_replies: true).new.to_json_schema[:schema] }

    it 'declares the welcome before the answer so the model writes it first' do
      expect(schema[:properties].keys.first).to eq(:welcome)
      expect(schema[:properties].keys.index(:welcome)).to be < schema[:properties].keys.index(:response_parts)
      expect(schema[:required]).to include(:welcome)
    end

    it 'tells the model to start the answer without greeting' do
      expect(schema.dig(:properties, :response_parts, :description)).to end_with(described_class::RESPONSE_PARTS_AFTER_WELCOME)
      expect(schema.dig(:properties, :welcome, :description)).to include('Never repeat it or greet again in response_parts')
    end
  end

  context 'without the welcome' do
    it 'keeps the answer first and its description unchanged' do
      schema = described_class.for(suggested_replies: true).new.to_json_schema[:schema]

      expect(schema[:properties].keys.first).to eq(:response_parts)
      expect(schema[:properties]).not_to have_key(:welcome)
      expect(schema.dig(:properties, :response_parts, :description)).to eq(described_class::RESPONSE_PARTS_DESCRIPTION)
      expect(described_class.new.to_json_schema.dig(:schema, :properties, :response_parts, :description))
        .to eq(described_class::RESPONSE_PARTS_DESCRIPTION)
    end
  end
end
