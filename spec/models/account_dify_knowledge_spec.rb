require 'rails_helper'

RSpec.describe Account, type: :model do
  include_context 'with Dify credential encryption'
  let(:account) { create(:account) }

  it 'stores the workspace key encrypted and excludes it from form values' do
    account.update!(dify_configuration: {
                      'base_url' => 'https://dify.example.test', 'knowledge_api_key' => 'private-workspace-key',
                      'embedding_model' => 'example-embedding', 'embedding_model_provider' => 'example/provider'
                    })

    expect(account.reload.dify_knowledge_api_key).to eq('private-workspace-key')
    expect(account.read_attribute_before_type_cast(:dify_knowledge_api_key)).not_to include('private-workspace-key')
    expect(account.dify_configuration).not_to have_key('knowledge_api_key')
    expect(account.settings.to_json).not_to include('dify', 'private-workspace-key')
  end

  it 'requires a complete configuration with a URL without embedded credentials' do
    account.assign_attributes(dify_base_url: 'https://user:password@dify.example.test', dify_knowledge_api_key: 'private-workspace-key')

    expect(account).not_to be_valid
    expect(account.errors[:dify_base_url]).to be_present
    expect(account.errors[:dify_embedding_model]).to be_present
  end
end
