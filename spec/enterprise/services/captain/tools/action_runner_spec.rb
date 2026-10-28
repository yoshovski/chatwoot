require 'rails_helper'

RSpec.describe Captain::Tools::ActionRunner do
  let(:account) { create(:account) }
  let(:params_schema) do
    [{ 'name' => 'order_number', 'type' => 'string', 'description' => 'Order number' },
     { 'name' => 'email', 'type' => 'string', 'description' => 'Customer email' }]
  end
  let(:lookup_step) do
    { 'key' => 'lookup', 'type' => 'request', 'method' => 'GET', 'url' => 'https://example.com/orders?number={{ order_number }}',
      'headers' => [{ 'name' => 'Accept', 'value' => 'application/json' }], 'body_type' => 'json', 'body' => '' }
  end
  let(:cancel_step) do
    { 'key' => 'cancel', 'type' => 'request', 'method' => 'POST', 'url' => 'https://example.com/orders/{{ outputs.order_id }}/cancel',
      'headers' => [], 'body_type' => 'json', 'body' => '{"requested_by": "{{ contact.email }}"}' }
  end
  let(:outputs) do
    [{ 'key' => 'order_id', 'step' => 'lookup', 'path' => 'order.id', 'type' => 'number', 'available_to_ai' => true, 'required' => true },
     { 'key' => 'order_email', 'step' => 'lookup', 'path' => 'order.email', 'type' => 'string', 'available_to_ai' => false, 'required' => false }]
  end
  let(:steps) { [lookup_step, cancel_step] }
  let(:tool) { create(:captain_custom_tool, account: account, param_schema: params_schema, steps: steps, outputs: outputs) }
  let(:contact) { { email: 'jane@example.com', phone_number: '+34 600 123 456', name: 'Jane', verified: false } }
  let(:order_body) { { order: { id: 1042, email: 'Jane@Example.com ' } }.to_json }

  def run_action(params = { order_number: '1042', email: 'jane@example.com' }, **)
    described_class.new(tool).run(params: params, contact: contact, **)
  end

  before do
    stub_request(:get, 'https://example.com/orders?number=1042').to_return(status: 200, body: order_body)
  end

  it 'runs the requests in order and passes outputs to later steps' do
    cancel = stub_request(:post, 'https://example.com/orders/1042/cancel')
             .with(body: '{"requested_by": "jane@example.com"}', headers: { 'Content-Type' => 'application/json' })
             .to_return(status: 201, body: '{"cancelled": true}')

    result = run_action

    expect(result).to be_ok
    expect(result.outputs).to eq('order_id' => 1042, 'order_email' => 'Jane@Example.com ')
    expect(result.step_results.map { |step| [step[:key], step[:status]] }).to eq([['lookup', 200], ['cancel', 201]])
    expect(result.last_request_body).to eq('{"cancelled": true}')
    expect(cancel).to have_been_requested.once
  end

  it 'stops after the given step' do
    result = run_action(stop_after: 'lookup')

    expect(result).to be_ok
    expect(result.step_results.pluck(:key)).to eq(['lookup'])
  end

  it 'continues from a later step with outputs saved earlier' do
    stub_request(:post, 'https://example.com/orders/77/cancel').to_return(status: 200, body: '{}')

    result = run_action(outputs: { 'order_id' => 77 }, start_at: 1)

    expect(result).to be_ok
    expect(result.step_results.pluck(:key)).to eq(['cancel'])
  end

  it 'stops with not_found when a required output is missing' do
    stub_request(:get, 'https://example.com/orders?number=1042').to_return(status: 200, body: '{"order": null}')

    result = run_action

    expect(result).not_to be_ok
    expect(result.error_kind).to eq(:not_found)
    expect(result.failed_step).to eq('lookup')
    expect(WebMock).not_to have_requested(:post, %r{/cancel})
  end

  it 'stops with http_error and the status on a non-2xx response' do
    stub_request(:get, 'https://example.com/orders?number=1042').to_return(status: 404, body: 'Not found')

    result = run_action

    expect(result.error_kind).to eq(:http_error)
    expect(result.status).to eq(404)
    expect(result.step_results.first[:ok]).to be(false)
  end

  it 'stops with request_failed on a network error' do
    stub_request(:get, 'https://example.com/orders?number=1042').to_raise(SocketError.new('down'))

    expect(run_action.error_kind).to eq(:request_failed)
  end

  it 'redacts auth headers in the step results' do
    tool.update!(auth_type: 'bearer', auth_config: { 'token' => 'secret-token' })

    result = run_action(stop_after: 'lookup')

    expect(result.step_results.first.dig(:request, :headers, 'Authorization')).to eq('[REDACTED]')
    expect(WebMock).to have_requested(:get, 'https://example.com/orders?number=1042').with(headers: { 'Authorization' => 'Bearer secret-token' })
  end

  it 'stops when the time budget is used up' do
    stub_const("#{described_class}::TIME_BUDGET", 0.05)
    stub_request(:get, 'https://example.com/orders?number=1042').to_return do
      sleep 0.06
      { status: 200, body: order_body }
    end

    result = run_action

    expect(result.error_kind).to eq(:timeout)
    expect(result.failed_step).to eq('cancel')
    expect(WebMock).not_to have_requested(:post, %r{/cancel})
  end

  describe 'verify steps' do
    let(:verify_step) do
      { 'key' => 'check', 'type' => 'verify', 'left' => '{{ outputs.order_email }}', 'right' => '{{ email }}', 'compare' => 'email' }
    end
    let(:steps) { [lookup_step, verify_step, cancel_step] }

    it 'passes when the values match and runs the next step' do
      stub_request(:post, 'https://example.com/orders/1042/cancel').to_return(status: 200, body: '{}')

      expect(run_action).to be_ok
    end

    it 'fails without running later steps when the values differ' do
      result = run_action({ order_number: '1042', email: 'someone@example.com' })

      expect(result.error_kind).to eq(:verification_failed)
      expect(result.failed_step).to eq('check')
      expect(WebMock).not_to have_requested(:post, %r{/cancel})
    end

    it 'fails when either side is blank' do
      stub_request(:get, 'https://example.com/orders?number=1042').to_return(status: 200, body: '{"order": {"id": 1042, "email": ""}}')

      expect(run_action({ order_number: '1042', email: '' }).error_kind).to eq(:verification_failed)
    end

    it 'fails when it requires a verified contact and the contact is not verified' do
      verify_step['require_verified_contact'] = true

      expect(run_action.error_kind).to eq(:verification_failed)
    end

    {
      'exact' => [%w[ABC ABC], %w[ABC abc]],
      'case_insensitive' => [%w[Madrid mADRID], %w[Madrid Paris]],
      'email' => [[' Jane@Example.com', 'jane@example.com '], ['jane@example.com', 'jane@example.org']],
      'phone' => [['+34 600 123 456', '600-123-456'], ['+34 600 123 456', '+34 600 123 457']],
      'not_equal' => [%w[shipped pending], %w[shipped shipped]],
      'contains' => [['Express Delivery', 'express'], ['Standard', 'express']],
      'not_contains' => [['Standard', 'express'], ['Express Delivery', 'express']],
      'starts_with' => [%w[ORD-1042 ord-], %w[INV-1042 ord-]],
      'one_of' => [['pending', 'Pending, on_hold'], ['shipped', 'pending, on_hold']],
      'not_one_of' => [['pending', 'shipped, delivered'], ['shipped', 'shipped, delivered']],
      'greater_than' => [%w[120.5 100], %w[abc 100]],
      'less_than' => [%w[3 14], %w[30 14]],
      'present' => [['ORD-1', ''], ['', '']]
    }.each do |compare, (matching, different)|
      it "compares #{compare} values" do
        verify = { 'key' => 'check', 'type' => 'verify', 'left' => '{{ order_number }}', 'right' => '{{ email }}', 'compare' => compare }
        tool.update!(steps: [verify, lookup_step], outputs: [])

        expect(run_action({ order_number: matching[0], email: matching[1] }, stop_after: 'check').step_results.last[:ok]).to be(true)
        expect(run_action({ order_number: different[0], email: different[1] }).error_kind).to eq(:verification_failed)
      end
    end
  end

  describe 'auth per request step' do
    it 'sends each step its own auth, or the auth of the step it reuses' do
      stub_request(:post, 'https://example.com/orders/1042/cancel').to_return(status: 200, body: '{}')
      check = { 'key' => 'recheck', 'type' => 'request', 'method' => 'GET', 'url' => 'https://example.com/orders?number=1042',
                'headers' => [], 'auth' => { 'same_as' => 'lookup' } }
      tool.update!(steps: [lookup_step.merge('auth' => { 'type' => 'bearer', 'token' => 'lookup-token' }),
                           cancel_step.merge('auth' => { 'type' => 'api_key', 'name' => 'X-Key', 'key' => 'cancel-key' }), check])

      expect(run_action).to be_ok
      expect(WebMock).to have_requested(:get, 'https://example.com/orders?number=1042')
        .with(headers: { 'Authorization' => 'Bearer lookup-token' }).twice
      own_key_only = ->(request) { request.headers['X-Key'] == 'cancel-key' && !request.headers.key?('Authorization') }
      expect(WebMock).to have_requested(:post, 'https://example.com/orders/1042/cancel').with(&own_key_only)
    end

    it "uses the action's auth for steps saved without one" do
      tool.update!(auth_type: 'bearer', auth_config: { 'token' => 'action-token' })

      run_action(stop_after: 'lookup')

      expect(WebMock).to have_requested(:get, 'https://example.com/orders?number=1042').with(headers: { 'Authorization' => 'Bearer action-token' })
    end
  end

  describe 'saving outputs to the contact' do
    let(:contact_record) { create(:contact, account: account, custom_attributes: { 'plan' => 'basic' }) }
    let(:state) { { account_id: account.id, contact: { id: contact_record.id } } }

    before do
      create(:custom_attribute_definition, account: account, attribute_model: 'contact_attribute', attribute_key: 'order_ref')
      tool.update!(steps: [lookup_step], outputs: [outputs.first.merge('contact_attribute' => 'order_ref')])
    end

    it 'saves mapped outputs after a live run that passed' do
      described_class.new(tool, state: state).run(params: { order_number: '1042' }, contact: contact)

      expect(contact_record.reload.custom_attributes).to eq('plan' => 'basic', 'order_ref' => 1042)
    end

    it 'saves nothing from a test run or a failed run' do
      described_class.new(tool, state: state, mode: :test).run(params: { order_number: '1042' }, contact: contact)
      stub_request(:get, 'https://example.com/orders?number=1').to_return(status: 404)
      described_class.new(tool, state: state).run(params: { order_number: '1' }, contact: contact)

      expect(contact_record.reload.custom_attributes).to eq('plan' => 'basic')
    end
  end
end
