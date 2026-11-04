require 'rails_helper'

RSpec.describe Captain::Tools::UpdateContactAttributeTool do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:contact) { create(:contact, account: account, custom_attributes: { 'source' => 'ad' }) }
  let(:conversation) { create(:conversation, account: account, contact: contact) }
  let(:tool_context) { Struct.new(:state).new({ conversation: { id: conversation.id }, contact: { id: contact.id } }) }

  def define(key, type, **attrs)
    create(:custom_attribute_definition, account: account, attribute_model: 'contact_attribute', attribute_key: key,
                                         attribute_display_name: key.humanize, attribute_display_type: type, **attrs)
  end

  it 'saves a number and names the tool after the attribute' do
    define('company_size', 'number')
    tool = described_class.new(assistant, fixed_params: { key: 'company_size' })

    expect(tool.name).to eq('captain--tools--update_contact_attribute__company_size')
    expect(tool.parameters.keys).to eq([:value])
    expect(tool.perform(tool_context, value: '40')).to eq('Saved Company size: 40')
    expect(contact.reload.custom_attributes).to eq('source' => 'ad', 'company_size' => 40)
  end

  it 'validates each display type' do
    define('size', 'number')
    define('plan', 'list', attribute_values: %w[Starter Growth])
    define('trial', 'checkbox')
    define('start', 'date')
    define('site', 'link')

    results = { 'size' => 'forty', 'plan' => 'growth', 'trial' => 'yes', 'start' => '2026-13-01', 'site' => 'example' }.to_h do |key, value|
      [key, described_class.new(assistant, fixed_params: { key: key }).perform(tool_context, value: value)]
    end

    expect(results['size']).to include('Expected a number')
    expect(results['plan']).to eq('Saved Plan: Growth')
    expect(results['trial']).to eq('Saved Trial: true')
    expect(results['start']).to include('YYYY-MM-DD')
    expect(results['site']).to include('http(s) link')
    expect(contact.reload.custom_attributes).to include('plan' => 'Growth', 'trial' => true)
  end

  it 'checks a text attribute against its regex' do
    define('vat', 'text', regex_pattern: '^[A-Z]{2}\d+$', regex_cue: 'like ES123')

    result = described_class.new(assistant, fixed_params: { key: 'vat' }).perform(tool_context, value: 'abc')

    expect(result).to include('like ES123')
  end

  it 'never touches name, email or phone' do
    define('phone', 'text')

    expect(described_class.fixed_param_errors(assistant, 'key' => 'email')).to eq(
      ["update_contact_attribute can't change email: the lead tools own name, email and phone"]
    )
    expect(described_class.new(assistant, fixed_params: { key: 'phone' }).perform(tool_context, value: '555 0100')).to include("isn't set up")
    expect(contact.reload.custom_attributes).not_to have_key('phone')
  end

  it 'reports a deleted attribute instead of saving' do
    expect(described_class.fixed_param_errors(assistant, 'key' => 'gone')).to eq(['no contact attribute gone'])
  end

  it 'saves nothing in the playground' do
    define('company_size', 'number')
    tool_context.state[:source] = 'playground'

    expect(described_class.new(assistant, fixed_params: { key: 'company_size' }).perform(tool_context, value: '40')).to include('preview')
    expect(contact.reload.custom_attributes).not_to have_key('company_size')
  end
end
