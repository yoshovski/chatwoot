require 'rails_helper'

RSpec.describe Captain::Reply::Builder do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account, config: { 'suggested_replies' => false }) }
  let(:run_result) { instance_double(Agents::RunResult, context: { state: {} }) }
  let(:context) { Captain::Reply::Context.build(assistant: assistant, run_result: run_result) }

  def build(response) = described_class.build(context, Captain::Reply::Draft.from_response(response))

  it 'runs the policies in a fixed order' do
    expect(described_class::POLICIES.map(&:name).map(&:demodulize))
      .to eq(%w[Greeting Answer Split FollowUp Suggestions Cards LeadForm Confirmation Channel])
  end

  it 'takes the closing question only out of the part it came from' do
    plan = build('response_parts' => [{ 'text' => 'Monthly or yearly? Plans differ in storage.', 'citation_indexes' => [] },
                                      { 'text' => 'Pausing keeps your notes safe for months. Monthly or yearly?', 'citation_indexes' => [] }])

    expect(plan.payloads(segment_kinds: false).pluck(:content))
      .to eq(["Monthly or yearly? Plans differ in storage.\n\nPausing keeps your notes safe for months.", 'Monthly or yearly?'])
  end

  it 'splits at the model indexes after a welcome the draft removed' do
    plan = build('welcome' => 'Hi there!', 'separate_parts' => [2],
                 'response_parts' => [{ 'text' => 'Hi there!', 'citation_indexes' => [] },
                                      { 'text' => 'Sync runs hourly.', 'citation_indexes' => [] },
                                      { 'text' => 'Offline works too.', 'citation_indexes' => [] }])

    expect(plan.kinds).to eq(%w[greeting answer answer])
    expect(plan.payloads.pluck(:content)).to eq(["Hi there!\n\nSync runs hourly.", 'Offline works too.'])
  end

  it 'reports an empty answer only when nothing explains it' do
    empty = ->(response) { described_class.empty_answer?(context, Captain::Reply::Draft.from_response(response)) }

    expect(empty.call({ 'response' => '', 'response_parts' => [] })).to be(true)
    expect(empty.call({ 'welcome' => 'Hi there!', 'response_parts' => [] })).to be(false)
  end

  context 'when the visitor was welcomed early' do
    let(:run_result) { instance_double(Agents::RunResult, context: { state: { first_ai_reply: false, welcomed_early: true } }) }

    it 'adds no greeting to the reply' do
      plan = build('welcome' => 'Hi there!', 'response_parts' => [{ 'text' => 'Sync runs hourly.', 'citation_indexes' => [] }])

      expect(plan.kinds).to eq(%w[answer])
      expect(plan.payloads.pluck(:content)).to eq(['Sync runs hourly.'])
    end
  end
end
