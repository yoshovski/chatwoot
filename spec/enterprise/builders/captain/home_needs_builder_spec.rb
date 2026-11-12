require 'rails_helper'

RSpec.describe Captain::HomeNeedsBuilder do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:inbox) { create(:inbox, account: account) }

  before { create(:inbox_member, user: agent, inbox: inbox) }

  def waiting(minutes, **attributes)
    create(:conversation, account: account, inbox: inbox, assignee: nil, waiting_since: minutes.minutes.ago, **attributes)
  end

  def gap(question, count)
    Captain::KnowledgeGap.create!(account: account, assistant: assistant, question: question, normalized_question: question.downcase,
                                  occurrences_count: count, last_seen_at: Time.current)
  end

  it 'is empty for a new account' do
    builder = described_class.new(account, admin)

    expect(builder.needs).to eq([])
    expect(builder.leads).to eq([])
  end

  it 'lists people waiting for a person, longest wait first, at most three' do
    oldest = waiting(40, contact: create(:contact, account: account, name: 'Marta R.'))
    [30, 20, 10].each { |minutes| waiting(minutes) }
    waiting(50, assignee: agent)
    create(:conversation, account: account, inbox: inbox, assignee: nil, waiting_since: nil)

    handoffs = described_class.new(account, admin).needs.select { |item| item[:key] == 'handoff' }

    expect(handoffs.size).to eq(3)
    expect(handoffs.first).to eq(key: 'handoff', id: oldest.display_id, name: 'Marta R.', inbox: inbox.name, at: oldest.waiting_since.to_i)
  end

  it 'lists the unanswered questions asked most often' do
    gap('Do you ship to Spain?', 2)
    often = gap('Do you ship to the Canary Islands?', 6)

    gaps = described_class.new(account, admin).needs.select { |item| item[:key] == 'gap' }

    expect(gaps.pluck(:question)).to eq(['Do you ship to the Canary Islands?', 'Do you ship to Spain?'])
    expect(gaps.first).to include(id: often.id, assistant_id: assistant.id, count: 6)
  end

  describe 'problems for administrators' do
    before do
      email_channel = create(:channel_email, account: account)
      email_channel.inbox.update!(name: 'Support mail')
      email_channel.prompt_reauthorization!
      create(:captain_document, account: account, assistant: assistant, name: 'Returns', sync_status: :failed,
                                last_sync_attempted_at: 2.hours.ago)
      Captain::WebsiteSource.create!(assistant: assistant, url: 'https://www.example.com', status: 'failed')
      create(:captain_scheduled_action, conversation: create(:conversation, account: account, inbox: inbox, assignee: agent), status: 'failed')
      Captain::McpServer.create!(account: account, name: 'Shop tools', endpoint_url: 'https://tools.example/mcp', status: 'failed')
    end

    it 'lists failed syncs, failed actions and channels that lost their connection' do
      keys = described_class.new(account, admin).needs.map { |item| [item[:key], item[:name] || item[:kind]] }

      expect(keys).to contain_exactly(%w[failed_sync Returns], ['failed_sync', 'https://www.example.com'],
                                      %w[failed_action follow_up_message], ['failed_action', 'Shop tools'],
                                      ['channel', 'Support mail'])
    end

    it 'leaves them out for agents' do
      expect(described_class.new(account, agent).needs).to eq([])
    end
  end

  it 'lists recent leads from the conversations the user can open' do
    lead = create(:conversation, account: account, inbox: inbox, contact: create(:contact, account: account, name: 'Ana'),
                                 additional_attributes: { 'business_lead_captured' => true })
    create(:conversation, account: account, additional_attributes: { 'business_lead_captured' => true })

    expect(described_class.new(account, agent).leads).to eq([{ id: lead.display_id, name: 'Ana', at: lead.last_activity_at.to_i }])
  end
end
