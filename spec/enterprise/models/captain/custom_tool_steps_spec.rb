require 'rails_helper'

RSpec.describe Captain::CustomTool, type: :model do
  let(:account) { create(:account) }
  let(:order_params) do
    [{ 'name' => 'order_number', 'type' => 'string', 'description' => 'Order number', 'test_value' => '1001' },
     { 'name' => 'email', 'type' => 'string', 'description' => 'Customer email' }]
  end
  let(:lookup_step) do
    { 'key' => 'lookup', 'type' => 'request', 'method' => 'GET', 'url' => 'https://api.example.com/orders?number={{ order_number }}',
      'headers' => [{ 'name' => 'Accept', 'value' => 'application/json' }], 'body_type' => 'json', 'body' => '' }
  end
  let(:verify_step) do
    { 'key' => 'check_email', 'type' => 'verify', 'left' => '{{ outputs.order_email }}', 'right' => '{{ email }}', 'compare' => 'email' }
  end
  let(:cancel_step) do
    { 'key' => 'cancel', 'type' => 'request', 'method' => 'POST', 'url' => 'https://api.example.com/orders/{{ outputs.order_id }}/cancel',
      'headers' => [], 'body_type' => 'json', 'body' => '{"reason": "{{ contact.email }}"}' }
  end
  let(:outputs) do
    [{ 'key' => 'order_email', 'step' => 'lookup', 'path' => 'order.email', 'type' => 'string', 'available_to_ai' => false, 'required' => true },
     { 'key' => 'order_id', 'step' => 'lookup', 'path' => 'order.id', 'type' => 'number', 'available_to_ai' => true, 'required' => true }]
  end

  def build_action(steps, **attrs)
    build(:captain_custom_tool, account: account, param_schema: order_params, steps: steps, outputs: outputs, **attrs)
  end

  describe 'steps' do
    it 'accepts a request, a verify on its output and a request that uses it' do
      tool = build_action([lookup_step, verify_step, cancel_step])

      expect(tool).to be_valid
    end

    it 'allows a test value on each param' do
      expect(build_action([lookup_step]).param_schema.first['test_value']).to eq('1001')
      expect(build_action([lookup_step])).to be_valid
    end

    it 'mirrors the first request step into the legacy columns' do
      tool = build_action([lookup_step, verify_step, cancel_step.merge('method' => 'PUT')])
      tool.save!

      expect(tool.endpoint_url).to eq(lookup_step['url'])
      expect(tool.http_method).to eq('GET')

      tool.update!(steps: [cancel_step.merge('key' => 'first', 'url' => 'https://api.example.com/cancel', 'method' => 'DELETE')], outputs: [])
      expect(tool.http_method).to eq('POST')
      expect(tool.endpoint_url).to eq('https://api.example.com/cancel')
    end

    it 'builds a request step from the legacy columns when none is given' do
      tool = create(:captain_custom_tool, :with_post, account: account, endpoint_url: 'https://api.example.com/orders')

      expect(tool.steps).to eq([{ 'key' => 'request', 'type' => 'request', 'method' => 'POST', 'url' => 'https://api.example.com/orders',
                                  'headers' => [], 'body_type' => 'json', 'body' => '{ "key": "{{ value }}" }' }])
    end

    it 'updates the first request step when an older client writes the legacy columns' do
      tool = create(:captain_custom_tool, account: account)
      tool.update!(endpoint_url: 'https://api.example.com/other')

      expect(tool.steps.first['url']).to eq('https://api.example.com/other')
    end

    it 'rejects more than three requests or two verify checks' do
      requests = (1..4).map { |n| lookup_step.merge('key' => "lookup_#{n}") }
      verifies = (1..3).map { |n| verify_step.merge('key' => "check_#{n}", 'left' => '{{ email }}') }

      expect(build_action(requests).tap(&:validate).errors.full_messages).to include('Steps can have at most 3 request steps')
      expect(build_action([lookup_step] + verifies).tap(&:validate).errors.full_messages).to include('Steps can have at most 2 verify steps')
    end

    it 'rejects duplicate and malformed keys' do
      expect(build_action([lookup_step, lookup_step]).tap(&:validate).errors.full_messages).to include('Steps have duplicate keys: lookup')
      expect(build_action([lookup_step.merge('key' => 'Look Up')])).not_to be_valid
    end

    it 'rejects an action without a request step' do
      tool = build_action([verify_step.merge('left' => '{{ email }}')], endpoint_url: nil)

      expect(tool.tap(&:validate).errors.full_messages).to include('Steps must include a request step')
    end

    it 'rejects unknown variables' do
      tool = build_action([lookup_step.merge('url' => 'https://api.example.com/{{ customer_id }}?x={{ contact.address }}')])

      expect(tool).not_to be_valid
      expect(tool.errors[:'steps.lookup']).to include('uses unknown variables: customer_id, contact.address')
    end

    it 'rejects outputs of the same or a later step' do
      tool = build_action([verify_step, lookup_step])

      expect(tool).not_to be_valid
      expect(tool.errors[:'steps.check_email']).to include('uses unknown variables: outputs.order_email')
    end

    it 'checks the URL of every request step' do
      tool = build_action([lookup_step, cancel_step.merge('url' => 'http://localhost/cancel')])

      expect(tool).not_to be_valid
      expect(tool.errors[:'steps.cancel']).to include('URL must use HTTPS protocol', 'URL cannot use disallowed hostname')
    end

    it 'rejects outputs that point to a missing step' do
      tool = build_action([lookup_step], outputs: [outputs.first.merge('step' => 'missing')])

      expect(tool.tap(&:validate).errors.full_messages).to include('Outputs order email must come from a request step')
    end
  end

  describe 'execution mode' do
    it 'defaults to background when every request is GET' do
      expect(create(:captain_custom_tool, account: account, param_schema: order_params, steps: [lookup_step]).execution_mode).to eq('background')
    end

    it 'defaults to confirm when a request changes data' do
      tool = create(:captain_custom_tool, account: account, param_schema: order_params, steps: [lookup_step, cancel_step], outputs: outputs)

      expect(tool.execution_mode).to eq('confirm')
    end

    it 'keeps the mode the merchant chose' do
      tool = create(:captain_custom_tool, account: account, param_schema: order_params, steps: [lookup_step, cancel_step], outputs: outputs,
                                          execution_mode: 'background')

      expect(tool.execution_mode).to eq('background')
    end
  end

  describe 'auth secrets' do
    it 'stores secrets outside auth_config and keeps them on a blank update' do
      tool = build(:captain_custom_tool, account: account, auth_type: 'api_key')
      tool.assign_auth('name' => 'X-API-Key', 'key' => 'secret-key')
      tool.save!

      expect(tool.reload.auth_config).to eq('name' => 'X-API-Key')
      expect(tool.build_auth_headers).to eq('X-API-Key' => 'secret-key')

      tool.assign_auth('name' => 'X-Other-Key', 'key' => '')
      tool.save!
      expect(tool.reload.build_auth_headers).to eq('X-Other-Key' => 'secret-key')
    end

    it 'drops stored secrets when the auth type changes' do
      tool = build(:captain_custom_tool, account: account, auth_type: 'bearer')
      tool.assign_auth('token' => 'old-token')
      tool.save!

      tool.auth_type = 'basic'
      tool.assign_auth('username' => 'user', 'password' => '')
      tool.save!

      expect(tool.reload.build_basic_auth_credentials).to eq(['user', nil])
    end

    it 'still reads legacy secrets from auth_config' do
      tool = create(:captain_custom_tool, :with_bearer_auth, account: account)

      expect(tool.build_auth_headers).to eq('Authorization' => 'Bearer test_bearer_token_123')
      expect(tool.auth_configured?).to be(true)
    end
  end

  describe 'auth per request step' do
    let(:own_auth) { { 'type' => 'bearer', 'token' => 'step-secret' } }

    it 'stores step secrets encrypted, outside the step, and keeps them on a blank update' do
      tool = build_action([lookup_step.merge('auth' => own_auth)])
      tool.save!

      expect(tool.reload.steps.first['auth']).to eq('type' => 'bearer')
      expect(tool.encrypted_auth).not_to include('step-secret') if Chatwoot.encryption_configured?
      tool.update!(steps: [lookup_step.merge('auth' => { 'type' => 'bearer', 'token' => '' })])
      expect(tool.reload.request_auth(tool.steps.first)['token']).to eq('step-secret')
      expect(tool.public_steps.first['auth_configured']).to be(true)
    end

    it 'drops a step secret when its auth type changes or the step is removed' do
      tool = build_action([lookup_step.merge('auth' => own_auth), cancel_step.merge('auth' => own_auth)])
      tool.save!

      tool.update!(steps: [lookup_step.merge('auth' => { 'type' => 'basic', 'username' => 'u', 'password' => '' })])

      expect(tool.reload.request_auth(tool.steps.first)['password']).to be_nil
      expect(tool.auth_secrets['steps']).to be_nil
    end

    it 'keeps step secrets when the action auth changes' do
      tool = build_action([lookup_step.merge('auth' => own_auth)])
      tool.save!

      tool.auth_type = 'api_key'
      tool.assign_auth('name' => 'X-Key', 'key' => 'action-key')
      tool.save!

      expect(tool.reload.request_auth(tool.steps.first)['token']).to eq('step-secret')
    end

    it 'only reuses the auth of an earlier request step and needs a header name for an API key' do
      tool = build_action([lookup_step.merge('auth' => { 'same_as' => 'cancel' }),
                           cancel_step.merge('auth' => { 'type' => 'api_key', 'name' => '' })])

      expect(tool).not_to be_valid
      expect(tool.errors[:'steps.lookup']).to include('can only reuse the auth of an earlier request step')
      expect(tool.errors[:'steps.cancel']).to include('API key auth needs a header name')
    end
  end

  describe 'check messages and contact attributes' do
    it 'rejects a check message with variables' do
      tool = build_action([lookup_step, verify_step.merge('failure_message' => 'Order {{ outputs.order_id }} has shipped')])

      expect(tool).not_to be_valid
      expect(tool.errors[:'steps.check_email']).to include("message can't use variables")
    end

    it 'saves an output only to an existing contact attribute' do
      create(:custom_attribute_definition, account: account, attribute_model: 'contact_attribute', attribute_key: 'order_ref')
      valid = build_action([lookup_step], outputs: [outputs.first.merge('contact_attribute' => 'order_ref')])
      invalid = build_action([lookup_step], outputs: [outputs.first.merge('contact_attribute' => 'missing')])

      expect(valid).to be_valid
      expect(invalid).not_to be_valid
      expect(invalid.errors[:'outputs.order_email']).to include('must be saved to an existing contact attribute')
    end
  end

  describe 'data migration' do
    require Rails.root.join('db/migrate/20261028120000_add_action_steps_to_captain_custom_tools.rb')

    let(:migration) { AddActionStepsToCaptainCustomTools.new }

    it 'gives legacy tools one request step and moves secrets into the encrypted column' do
      tool = create(:captain_custom_tool, :with_api_key, :with_post, account: account)
      tool.update_columns(steps: [], auth_config: { 'name' => 'X-API-Key', 'key' => 'legacy-key' }) # rubocop:disable Rails/SkipsModelValidations

      migration.send(:migrate_tool, AddActionStepsToCaptainCustomTools::MigrationCustomTool.find(tool.id))
      tool.reload

      expect(tool.steps).to eq([{ 'key' => 'request', 'type' => 'request', 'method' => 'POST', 'url' => tool.endpoint_url,
                                  'headers' => [], 'body_type' => 'json', 'body' => tool.request_template }])
      expect(tool.auth_config).to eq('name' => 'X-API-Key')
      expect(tool.auth_secrets).to eq('key' => 'legacy-key')
      expect(tool.outputs).to eq([])
    end

    it 'restores the secrets into auth_config on rollback' do
      tool = create(:captain_custom_tool, account: account, auth_type: 'bearer')
      tool.update_columns(auth_config: {}, encrypted_auth: { 'token' => 'kept' }.to_json) # rubocop:disable Rails/SkipsModelValidations

      migration.send(:restore_auth, AddActionStepsToCaptainCustomTools::MigrationCustomTool.find(tool.id))

      expect(tool.reload.auth_config).to eq('token' => 'kept')
    end
  end
end
