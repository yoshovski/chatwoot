require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Captain::CustomTools', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  before { account.enable_features!('custom_tools') }

  def json_response
    JSON.parse(response.body, symbolize_names: true)
  end

  describe 'GET /api/v1/accounts/{account.id}/captain/custom_tools' do
    context 'when it is an un-authenticated user' do
      it 'returns unauthorized status' do
        get "/api/v1/accounts/#{account.id}/captain/custom_tools"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an agent' do
      it 'returns success status' do
        create_list(:captain_custom_tool, 3, account: account)
        get "/api/v1/accounts/#{account.id}/captain/custom_tools",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response[:payload].length).to eq(3)
      end
    end

    context 'when it is an admin' do
      it 'returns success status and custom tools' do
        create_list(:captain_custom_tool, 5, account: account)
        get "/api/v1/accounts/#{account.id}/captain/custom_tools",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response[:payload].length).to eq(5)
      end

      it 'returns all custom tools including disabled' do
        create(:captain_custom_tool, account: account, enabled: true)
        create(:captain_custom_tool, account: account, enabled: false)
        get "/api/v1/accounts/#{account.id}/captain/custom_tools",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response[:payload].length).to eq(2)
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/captain/custom_tools/{id}' do
    let(:custom_tool) { create(:captain_custom_tool, account: account) }

    context 'when it is an un-authenticated user' do
      it 'returns unauthorized status' do
        get "/api/v1/accounts/#{account.id}/captain/custom_tools/#{custom_tool.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an agent' do
      it 'returns success status and custom tool' do
        get "/api/v1/accounts/#{account.id}/captain/custom_tools/#{custom_tool.id}",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response[:id]).to eq(custom_tool.id)
        expect(json_response[:title]).to eq(custom_tool.title)
      end
    end

    context 'when custom tool does not exist' do
      it 'returns not found status' do
        get "/api/v1/accounts/#{account.id}/captain/custom_tools/999999",
            headers: agent.create_new_auth_token

        expect(response).to have_http_status(:not_found)
      end
    end

    it 'returns the number of enabled scenarios referencing the tool' do
      custom_tool.update!(slug: 'custom_fetch-order')
      assistant = create(:captain_assistant, account: account)
      instruction = 'Use [@Fetch Order](tool://custom_fetch-order) to get order details'
      create(:captain_scenario, assistant: assistant, account: account, instruction: instruction, enabled: true)
      create(:captain_scenario, assistant: assistant, account: account, instruction: instruction, enabled: false)

      get "/api/v1/accounts/#{account.id}/captain/custom_tools/#{custom_tool.id}",
          headers: admin.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(json_response[:enabled_scenarios_count]).to eq(1)
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/captain/custom_tools' do
    let(:valid_attributes) do
      {
        custom_tool: {
          title: 'Fetch Order Status',
          description: 'Fetches order status from external API',
          endpoint_url: 'https://api.example.com/orders/{{ order_id }}',
          http_method: 'GET',
          enabled: true,
          param_schema: [
            { name: 'order_id', type: 'string', description: 'The order ID', required: true }
          ]
        }
      }
    end

    context 'when it is an un-authenticated user' do
      it 'returns unauthorized status' do
        post "/api/v1/accounts/#{account.id}/captain/custom_tools",
             params: valid_attributes
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an agent' do
      it 'returns unauthorized status' do
        post "/api/v1/accounts/#{account.id}/captain/custom_tools",
             params: valid_attributes,
             headers: agent.create_new_auth_token
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an admin' do
      it 'creates a new custom tool and returns success status' do
        post "/api/v1/accounts/#{account.id}/captain/custom_tools",
             params: valid_attributes,
             headers: admin.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(json_response[:title]).to eq('Fetch Order Status')
        expect(json_response[:description]).to eq('Fetches order status from external API')
        expect(json_response[:enabled]).to be(true)
        expect(json_response[:slug]).to eq('custom_fetch_order_status')
        expect(json_response[:param_schema]).to eq([
                                                     { name: 'order_id', type: 'string', description: 'The order ID', required: true }
                                                   ])
      end

      context 'with invalid parameters' do
        let(:invalid_attributes) do
          {
            custom_tool: {
              title: '',
              endpoint_url: ''
            }
          }
        end

        it 'returns unprocessable entity status' do
          post "/api/v1/accounts/#{account.id}/captain/custom_tools",
               params: invalid_attributes,
               headers: admin.create_new_auth_token,
               as: :json

          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context 'with invalid endpoint URL' do
        let(:invalid_url_attributes) do
          {
            custom_tool: {
              title: 'Test Tool',
              endpoint_url: 'http://localhost/api',
              http_method: 'GET'
            }
          }
        end

        it 'returns unprocessable entity status' do
          post "/api/v1/accounts/#{account.id}/captain/custom_tools",
               params: invalid_url_attributes,
               headers: admin.create_new_auth_token,
               as: :json

          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/captain/custom_tools/{id}' do
    let(:custom_tool) { create(:captain_custom_tool, account: account) }
    let(:update_attributes) do
      {
        custom_tool: {
          title: 'Updated Tool Title',
          enabled: false
        }
      }
    end

    context 'when it is an un-authenticated user' do
      it 'returns unauthorized status' do
        patch "/api/v1/accounts/#{account.id}/captain/custom_tools/#{custom_tool.id}",
              params: update_attributes
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an agent' do
      it 'returns unauthorized status' do
        patch "/api/v1/accounts/#{account.id}/captain/custom_tools/#{custom_tool.id}",
              params: update_attributes,
              headers: agent.create_new_auth_token
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an admin' do
      it 'updates the custom tool and returns success status' do
        patch "/api/v1/accounts/#{account.id}/captain/custom_tools/#{custom_tool.id}",
              params: update_attributes,
              headers: admin.create_new_auth_token,
              as: :json

        expect(response).to have_http_status(:success)
        expect(json_response[:title]).to eq('Updated Tool Title')
        expect(json_response[:enabled]).to be(false)
        expect(custom_tool.reload.enabled).to be(false)
      end

      context 'with invalid parameters' do
        let(:invalid_attributes) do
          {
            custom_tool: {
              title: ''
            }
          }
        end

        it 'returns unprocessable entity status' do
          patch "/api/v1/accounts/#{account.id}/captain/custom_tools/#{custom_tool.id}",
                params: invalid_attributes,
                headers: admin.create_new_auth_token,
                as: :json

          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end
  end

  describe 'auth secrets' do
    let(:custom_tool) { create(:captain_custom_tool, account: account, auth_type: 'api_key') }

    before do
      custom_tool.assign_auth('name' => 'X-API-Key', 'key' => 'stored-secret')
      custom_tool.save!
    end

    it 'never returns secrets, only that auth is configured' do
      get "/api/v1/accounts/#{account.id}/captain/custom_tools/#{custom_tool.id}",
          headers: admin.create_new_auth_token,
          as: :json

      expect(response.body).not_to include('stored-secret')
      expect(json_response[:auth_config]).to eq(name: 'X-API-Key')
      expect(json_response[:auth_configured]).to be(true)
    end

    it 'keeps the stored secret when the update leaves it blank' do
      patch "/api/v1/accounts/#{account.id}/captain/custom_tools/#{custom_tool.id}",
            params: { custom_tool: { auth_config: { name: 'X-Key', key: '' } } },
            headers: admin.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      expect(custom_tool.reload.build_auth_headers).to eq('X-Key' => 'stored-secret')
    end

    it 'stores a new secret encrypted instead of in auth_config' do
      patch "/api/v1/accounts/#{account.id}/captain/custom_tools/#{custom_tool.id}",
            params: { custom_tool: { auth_config: { name: 'X-API-Key', key: 'new-secret' } } },
            headers: admin.create_new_auth_token,
            as: :json

      expect(custom_tool.reload.auth_config).to eq('name' => 'X-API-Key')
      expect(custom_tool.auth_secrets).to eq('key' => 'new-secret')
    end

    it "stores a step's own secret and only says that it is configured" do
      step = custom_tool.steps.first.merge('auth' => { 'type' => 'bearer', 'token' => 'step-secret' })
      patch "/api/v1/accounts/#{account.id}/captain/custom_tools/#{custom_tool.id}",
            params: { custom_tool: { steps: [step] } },
            headers: admin.create_new_auth_token,
            as: :json

      expect(response.body).not_to include('step-secret')
      expect(json_response[:steps].first[:auth]).to eq(type: 'bearer')
      expect(json_response[:steps].first[:auth_configured]).to be(true)
      expect(custom_tool.reload.request_auth(custom_tool.steps.first)['token']).to eq('step-secret')
    end
  end

  describe 'action fields' do
    let(:action_attributes) do
      {
        custom_tool: {
          title: 'Look up order',
          description: 'Finds an order',
          execution_mode: 'background',
          param_schema: [{ name: 'order_number', type: 'string', description: 'Order number', required: true, test_value: '1042' }],
          steps: [{ key: 'lookup', type: 'request', method: 'GET', url: 'https://example.com/orders/{{ order_number }}',
                    headers: [{ name: 'Accept', value: 'application/json' }], body_type: 'json', body: '' }],
          outputs: [{ key: 'status', step: 'lookup', path: 'order.status', type: 'string', available_to_ai: true, required: true }],
          messages: { success: 'Done' }
        }
      }
    end

    it 'saves steps, outputs, execution mode, messages and test values' do
      post "/api/v1/accounts/#{account.id}/captain/custom_tools",
           params: action_attributes,
           headers: admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      tool = Captain::CustomTool.find(json_response[:id])
      expect(tool.steps.first).to include('key' => 'lookup', 'method' => 'GET', 'headers' => [{ 'name' => 'Accept', 'value' => 'application/json' }])
      expect(tool.outputs.first).to include('key' => 'status', 'available_to_ai' => true)
      expect(tool.param_schema.first['test_value']).to eq('1042')
      expect(tool.messages).to eq('success' => 'Done')
      expect(tool.endpoint_url).to eq('https://example.com/orders/{{ order_number }}')
    end

    it 'returns step errors by attribute' do
      action_attributes[:custom_tool][:steps].first[:url] = 'https://example.com/{{ missing }}'

      post "/api/v1/accounts/#{account.id}/captain/custom_tools",
           params: action_attributes,
           headers: admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response[:errors][:'steps.lookup']).to eq(['uses unknown variables: missing'])
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/captain/custom_tools/test' do
    let(:test_attributes) do
      {
        custom_tool: {
          title: 'Look up order',
          param_schema: [{ name: 'order_number', type: 'string', description: 'Order number', test_value: '1042' },
                         { name: 'email', type: 'string', description: 'Email', test_value: 'jane@example.com' }],
          steps: [
            { key: 'lookup', type: 'request', method: 'GET', url: 'https://example.com/orders/{{ order_number }}', headers: [], body_type: 'json' },
            { key: 'check', type: 'verify', left: '{{ outputs.order_email }}', right: '{{ email }}', compare: 'email' },
            { key: 'cancel', type: 'request', method: 'POST', url: 'https://example.com/orders/{{ order_number }}/cancel', headers: [],
              body_type: 'json', body: '{}' }
          ],
          outputs: [{ key: 'order_email', step: 'lookup', path: 'order.email', type: 'string', available_to_ai: false, required: true }]
        }
      }
    end

    before do
      stub_request(:get, 'https://example.com/orders/1042').to_return(status: 200, body: { order: { email: 'jane@example.com' } }.to_json)
      stub_request(:post, 'https://example.com/orders/1042/cancel').to_return(status: 200, body: 'cancelled')
    end

    after { Redis::Alfred.delete(format(Redis::Alfred::CAPTAIN_ACTION_TEST_COUNT, user_id: admin.id, minute: Time.current.to_i / 60)) }

    it 'runs every step with the test values and returns each response' do
      post "/api/v1/accounts/#{account.id}/captain/custom_tools/test",
           params: test_attributes,
           headers: admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(json_response[:steps].pluck(:key)).to eq(%w[lookup check cancel])
      expect(json_response[:steps].first).to include(ok: true, status: 200, response: { order: { email: 'jane@example.com' } })
      expect(json_response[:steps].first[:request]).to include(method: 'GET', url: 'https://example.com/orders/1042')
      expect(json_response[:steps].last[:response]).to eq('cancelled')
      expect(json_response[:outputs]).to eq(order_email: 'jane@example.com')
      expect(json_response[:error_kind]).to be_nil
    end

    it 'stops after the given step and lets the request override test values' do
      stub_request(:get, 'https://example.com/orders/7').to_return(status: 200, body: { order: { email: 'x@example.com' } }.to_json)

      post "/api/v1/accounts/#{account.id}/captain/custom_tools/test",
           params: test_attributes.merge(stop_after: 'lookup', test_values: { order_number: '7' }),
           headers: admin.create_new_auth_token,
           as: :json

      expect(json_response[:steps].pluck(:key)).to eq(['lookup'])
      expect(WebMock).not_to have_requested(:post, %r{/cancel})
    end

    it 'reports a failed verify step' do
      post "/api/v1/accounts/#{account.id}/captain/custom_tools/test",
           params: test_attributes.merge(test_values: { email: 'other@example.com' }),
           headers: admin.create_new_auth_token,
           as: :json

      expect(json_response[:error_kind]).to eq('verification_failed')
      expect(json_response[:steps].last).to include(key: 'check', ok: false, compared: { left: 'jane@example.com', right: 'other@example.com' })
    end

    it 'uses the stored secrets of a saved tool and redacts them' do
      tool = create(:captain_custom_tool, account: account, auth_type: 'bearer')
      tool.assign_auth('token' => 'stored-token')
      tool.save!
      test_attributes[:custom_tool].merge!(auth_type: 'bearer', auth_config: { token: '' })

      post "/api/v1/accounts/#{account.id}/captain/custom_tools/test",
           params: test_attributes.merge(id: tool.id, stop_after: 'lookup'),
           headers: admin.create_new_auth_token,
           as: :json

      expect(WebMock).to have_requested(:get, 'https://example.com/orders/1042').with(headers: { 'Authorization' => 'Bearer stored-token' })
      expect(response.body).not_to include('stored-token')
      expect(json_response[:steps].first.dig(:request, :headers, :Authorization)).to eq('[REDACTED]')
      expect(tool.reload.steps.first['url']).to eq('https://api.example.com/endpoint')
    end

    it 'removes credentials from the echoed URL' do
      test_attributes[:custom_tool][:steps] =
        [{ key: 'lookup', type: 'request', method: 'GET', url: 'https://user:pass@example.com/orders/{{ order_number }}' }]
      test_attributes[:custom_tool][:outputs] = []
      stub_request(:get, 'https://example.com/orders/1042').with(basic_auth: %w[user pass]).to_return(status: 200, body: '{}')

      post "/api/v1/accounts/#{account.id}/captain/custom_tools/test",
           params: test_attributes,
           headers: admin.create_new_auth_token,
           as: :json

      expect(json_response[:steps].first.dig(:request, :url)).to eq('https://example.com/orders/1042')
    end

    it 'returns validation errors for the steps without calling the API' do
      test_attributes[:custom_tool][:steps].first[:url] = 'http://localhost/orders'

      post "/api/v1/accounts/#{account.id}/captain/custom_tools/test",
           params: test_attributes,
           headers: admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response[:errors]).to have_key(:'steps.lookup')
    end

    it 'allows 20 test runs per user per minute' do
      Redis::Alfred.set(format(Redis::Alfred::CAPTAIN_ACTION_TEST_COUNT, user_id: admin.id, minute: Time.current.to_i / 60), 20)

      post "/api/v1/accounts/#{account.id}/captain/custom_tools/test",
           params: test_attributes,
           headers: admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:too_many_requests)
      expect(WebMock).not_to have_requested(:get, 'https://example.com/orders/1042')
    end

    it 'is not available to agents' do
      post "/api/v1/accounts/#{account.id}/captain/custom_tools/test",
           params: test_attributes,
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/captain/custom_tools/{id}' do
    let!(:custom_tool) { create(:captain_custom_tool, account: account) }

    context 'when it is an un-authenticated user' do
      it 'returns unauthorized status' do
        delete "/api/v1/accounts/#{account.id}/captain/custom_tools/#{custom_tool.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an agent' do
      it 'returns unauthorized status' do
        delete "/api/v1/accounts/#{account.id}/captain/custom_tools/#{custom_tool.id}",
               headers: agent.create_new_auth_token
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an admin' do
      it 'deletes the custom tool and returns no content status' do
        expect do
          delete "/api/v1/accounts/#{account.id}/captain/custom_tools/#{custom_tool.id}",
                 headers: admin.create_new_auth_token
        end.to change(Captain::CustomTool, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end

      context 'when custom tool does not exist' do
        it 'returns not found status' do
          delete "/api/v1/accounts/#{account.id}/captain/custom_tools/999999",
                 headers: admin.create_new_auth_token

          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end
end
