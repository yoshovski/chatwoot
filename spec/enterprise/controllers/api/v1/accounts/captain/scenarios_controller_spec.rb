require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Captain::Scenarios', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:assistant) { create(:captain_assistant, account: account) }

  def json_response
    JSON.parse(response.body, symbolize_names: true)
  end

  describe 'GET /api/v1/accounts/{account.id}/captain/assistants/{assistant.id}/scenarios' do
    context 'when it is an un-authenticated user' do
      it 'returns unauthorized status' do
        get "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/scenarios"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an agent' do
      it 'returns success status' do
        create_list(:captain_scenario, 3, assistant: assistant, account: account)
        get "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/scenarios",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response[:payload].length).to eq(3)
      end
    end

    context 'when it is an admin' do
      it 'returns success status and scenarios' do
        create_list(:captain_scenario, 5, assistant: assistant, account: account)
        get "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/scenarios",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response[:payload].length).to eq(5)
      end

      it 'returns enabled and disabled scenarios' do
        enabled_scenario = create(:captain_scenario, assistant: assistant, account: account, enabled: true)
        disabled_scenario = create(:captain_scenario, assistant: assistant, account: account, enabled: false)
        get "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/scenarios",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response[:payload]).to contain_exactly(
          hash_including(id: enabled_scenario.id, enabled: true),
          hash_including(id: disabled_scenario.id, enabled: false)
        )
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/captain/assistants/{assistant.id}/scenarios/{id}' do
    let(:scenario) { create(:captain_scenario, assistant: assistant, account: account) }

    context 'when it is an un-authenticated user' do
      it 'returns unauthorized status' do
        get "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/scenarios/#{scenario.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an agent' do
      it 'returns success status and scenario' do
        get "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/scenarios/#{scenario.id}",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response[:id]).to eq(scenario.id)
        expect(json_response[:title]).to eq(scenario.title)
      end
    end

    context 'when scenario does not exist' do
      it 'returns not found status' do
        get "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/scenarios/999999",
            headers: agent.create_new_auth_token

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/captain/assistants/{assistant.id}/scenarios' do
    let(:valid_attributes) do
      {
        scenario: {
          title: 'Test Scenario',
          description: 'Test description',
          instruction: 'Test instruction',
          enabled: true,
          tools: %w[tool1 tool2]
        }
      }
    end

    context 'when it is an un-authenticated user' do
      it 'returns unauthorized status' do
        post "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/scenarios",
             params: valid_attributes
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an agent' do
      it 'returns unauthorized status' do
        post "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/scenarios",
             params: valid_attributes,
             headers: agent.create_new_auth_token
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an admin' do
      it 'creates a new scenario and returns success status' do
        expect do
          post "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/scenarios",
               params: valid_attributes,
               headers: admin.create_new_auth_token,
               as: :json
        end.to change(Captain::Scenario, :count).by(1)

        expect(response).to have_http_status(:success)
        expect(json_response[:title]).to eq('Test Scenario')
        expect(json_response[:description]).to eq('Test description')
        expect(json_response[:enabled]).to be(true)
        expect(json_response[:assistant_id]).to eq(assistant.id)
      end

      context 'with invalid parameters' do
        let(:invalid_attributes) do
          {
            scenario: {
              title: '',
              description: '',
              instruction: ''
            }
          }
        end

        it 'returns unprocessable entity status' do
          post "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/scenarios",
               params: invalid_attributes,
               headers: admin.create_new_auth_token,
               as: :json

          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/captain/assistants/{assistant.id}/scenarios/{id}' do
    let(:scenario) { create(:captain_scenario, assistant: assistant, account: account) }
    let(:update_attributes) do
      {
        scenario: {
          title: 'Updated Scenario Title',
          enabled: false
        }
      }
    end

    context 'when it is an un-authenticated user' do
      it 'returns unauthorized status' do
        patch "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/scenarios/#{scenario.id}",
              params: update_attributes
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an agent' do
      it 'returns unauthorized status' do
        patch "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/scenarios/#{scenario.id}",
              params: update_attributes,
              headers: agent.create_new_auth_token
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an admin' do
      it 'updates the scenario and returns success status' do
        patch "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/scenarios/#{scenario.id}",
              params: update_attributes,
              headers: admin.create_new_auth_token,
              as: :json

        expect(response).to have_http_status(:success)
        expect(json_response[:title]).to eq('Updated Scenario Title')
        expect(json_response[:enabled]).to be(false)
        expect(scenario.reload.enabled).to be(false)
      end

      context 'with invalid parameters' do
        let(:invalid_attributes) do
          {
            scenario: {
              title: ''
            }
          }
        end

        it 'returns unprocessable entity status' do
          patch "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/scenarios/#{scenario.id}",
                params: invalid_attributes,
                headers: admin.create_new_auth_token,
                as: :json

          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/captain/assistants/{assistant.id}/scenarios/{id}' do
    let!(:scenario) { create(:captain_scenario, assistant: assistant, account: account) }

    context 'when it is an un-authenticated user' do
      it 'returns unauthorized status' do
        delete "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/scenarios/#{scenario.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an agent' do
      it 'returns unauthorized status' do
        delete "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/scenarios/#{scenario.id}",
               headers: agent.create_new_auth_token
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an admin' do
      it 'deletes the scenario and returns no content status' do
        expect do
          delete "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/scenarios/#{scenario.id}",
                 headers: admin.create_new_auth_token
        end.to change(Captain::Scenario, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end

      context 'when scenario does not exist' do
        it 'returns not found status' do
          delete "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/scenarios/999999",
                 headers: admin.create_new_auth_token

          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/captain/assistants/{assistant.id}/scenarios/draft' do
    let(:draft_prompt) { 'Collect quote requests from customers and hand off to our team' }
    let(:draft_result) do
      {
        title: 'Request a quote',
        description: 'Use when the customer asks for a quote or bulk pricing.',
        instruction: "1. Collect details\n2. [@Find products](tool://catalog_product_search)",
        tools: ['catalog_product_search'],
        notes: []
      }
    end

    context 'when it is an un-authenticated user' do
      it 'returns unauthorized status' do
        post "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/scenarios/draft",
             params: { description: draft_prompt }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an agent' do
      it 'returns unauthorized status' do
        post "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/scenarios/draft",
             headers: agent.create_new_auth_token,
             params: { description: draft_prompt }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an admin' do
      it 'returns 200 with generated scenario draft' do
        service = instance_double(Captain::Llm::ScenarioDraftService, perform: draft_result)
        expect(Captain::Llm::ScenarioDraftService).to receive(:new).with(
          assistant: assistant,
          user_prompt: draft_prompt
        ).and_return(service)

        post "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/scenarios/draft",
             headers: admin.create_new_auth_token,
             params: { description: draft_prompt },
             as: :json

        expect(response).to have_http_status(:success)
        expect(json_response[:title]).to eq('Request a quote')
        expect(json_response[:tools]).to eq(['catalog_product_search'])
      end

      it 'returns 422 if description is too short' do
        post "/api/v1/accounts/#{account.id}/captain/assistants/#{assistant.id}/scenarios/draft",
             headers: admin.create_new_auth_token,
             params: { description: 'short' },
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
