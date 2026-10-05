require 'rails_helper'

RSpec.describe 'Captain Dify dataset configuration', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:assistant) do
    create(:captain_assistant, account: account,
                               config: { 'dify_faq_dataset_id' => 'faq-id', 'dify_docs_dataset_id' => 'docs-id',
                                         'dify_extra_dataset_ids' => ['extra-id'], 'dify_faq_qa_dataset_id' => 'staging-id',
                                         'dify_legacy_faq_dataset_id' => 'legacy-id' })
  end

  it 'hides dataset IDs and rejects client changes while preserving public configuration' do
    patch "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}",
          headers: admin.create_new_auth_token,
          params: { assistant: { config: { product_name: 'Example', dify_faq_dataset_id: 'foreign-id',
                                           dify_extra_dataset_ids: ['foreign-id'] } } }, as: :json

    expect(response).to have_http_status(:success)
    expect(assistant.reload.config).to include('product_name' => 'Example', 'dify_faq_dataset_id' => 'faq-id',
                                               'dify_extra_dataset_ids' => ['extra-id'])
    expect(response.parsed_body['config']).not_to include('dify_faq_dataset_id', 'dify_docs_dataset_id', 'dify_extra_dataset_ids',
                                                          'dify_faq_qa_dataset_id', 'dify_legacy_faq_dataset_id')
  end
end
