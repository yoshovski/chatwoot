require 'rails_helper'

RSpec.describe Captain::SegmentRules do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, :with_email, account: account, created_at: 10.days.ago) }
  let(:assistant) { create(:captain_assistant, account: account, response_guidelines: ['Always be clear', 'Welcome new visitors']) }
  let(:context) { { response_guidelines: assistant.response_guidelines, guardrails: ['Never invent prices'] } }

  before do
    assistant.update!(config: { rule_segments: { response_guidelines: { 'Welcome new visitors' => 'new' } } })
  end

  it 'omits rules outside the segment and keeps unscoped rules' do
    expect(described_class.new(assistant, contact).apply(context)[:response_guidelines]).to eq(['Always be clear'])
    contact.update!(created_at: Time.current)
    expect(described_class.new(assistant, contact).apply(context)[:response_guidelines]).to eq(assistant.response_guidelines)
  end

  it 'omits scoped rules when no contact is available' do
    expect(described_class.new(assistant, nil).apply(context)[:response_guidelines]).to eq(['Always be clear'])
  end

  it 'does not mutate the shared prompt context' do
    described_class.new(assistant, contact).apply(context)
    expect(context[:response_guidelines]).to eq(assistant.response_guidelines)
  end

  it 'rejects rule references from another account' do
    saved = create(:custom_filter, filter_type: :contact)
    assistant.config['rule_segments']['response_guidelines']['Welcome new visitors'] = "custom:#{saved.id}"
    expect(assistant).not_to be_valid
  end

  it 'matches a saved audience by reference and stops matching after deletion' do
    saved = create(:custom_filter, account: account, filter_type: :contact, query: { payload: [] })
    matcher = Captain::AudienceMatcher.new({ 'segment_id' => "custom:#{saved.id}" })
    expect(matcher.matches?(contact, nil)).to be(true)
    saved.destroy!
    expect(matcher.matches?(contact, nil)).to be(false)
  end
end
