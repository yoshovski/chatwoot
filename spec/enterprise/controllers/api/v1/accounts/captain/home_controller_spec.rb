require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Captain::Home', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:url) { "/api/v1/accounts/#{account.id}/captain/home" }

  it 'returns the whole page for a new account in one response' do
    get url, headers: admin.create_new_auth_token, as: :json

    body = response.parsed_body
    expect(response).to have_http_status(:success)
    expect(body.keys).to contain_exactly('status', 'site', 'period', 'metrics', 'days', 'topics', 'needs', 'leads', 'setup',
                                         'project_status', 'usage')
    expect(body).to include('status' => 'needs_attention', 'site' => nil, 'period' => 7, 'needs' => [], 'leads' => [], 'topics' => [])
    expect(body['metrics'].keys).to contain_exactly('ai_conversations', 'resolved', 'handed', 'rating', 'product_answers')
    expect(body['days'].size).to eq(7)
    expect(body['setup']).to include('ai_agent' => false, 'knowledge' => false, 'chat_widget' => false, 'mailbox' => false)
    expect(body['project_status']).to include('widget_installed' => false, 'domain' => 'none')
  end

  it 'returns 30 days when asked' do
    get url, params: { period: 30, timezone_offset: '1' }, headers: admin.create_new_auth_token

    expect(response.parsed_body['period']).to eq(30)
    expect(response.parsed_body['days'].size).to eq(30)
  end

  it 'rejects any other period' do
    get url, params: { period: 90 }, headers: admin.create_new_auth_token

    expect(response).to have_http_status(:unprocessable_entity)
  end

  describe 'with data' do
    let(:assistant) { create(:captain_assistant, account: account) }
    let(:widget_inbox) { create(:inbox, account: account, channel: create(:channel_widget, account: account)) }
    let(:conversation) { create(:conversation, account: account, inbox: widget_inbox, assignee: nil) }

    before do
      create(:inbox_member, user: agent, inbox: widget_inbox)
      conversation # opened before the AI agent joins the inbox, so it isn't pending
      create(:captain_inbox, captain_assistant: assistant, inbox: widget_inbox)
      create(:captain_assistant_response, assistant: assistant, account: account, status: :approved)
      Captain::KnowledgeGaps::Recorder.new(assistant: assistant, conversation: conversation, question: 'Do you ship to Spain?',
                                           reason: 'handoff').record.knowledge!
      Captain::AgentSession.create!(assistant: assistant, session_type: :assistant, subject: conversation,
                                    sources: [{ index: 1, reference: 'product:mug', kind: 'product', used: true }])
      note = create(:message, account: account, conversation: conversation, private: true, message_type: :outgoing)
      conversation.update!(additional_attributes: { 'business_lead_captured' => true, 'business_lead_summary_note_id' => note.id })
      create(:portal, account: account, custom_domain: 'help.example.com', ssl_settings: { 'cf_status' => 'active' })
    end

    it 'fills each card for an agent' do
      widget_inbox.channel.update!(website_url: 'https://www.forma-store.com/shop')

      get url, headers: agent.create_new_auth_token, as: :json

      body = response.parsed_body
      expect(body).to include('status' => 'live', 'site' => 'forma-store.com')
      expect(body['setup']).to include('ai_agent' => true, 'knowledge' => true, 'agent_inbox' => true, 'chat_widget' => true,
                                       'teammate' => true)
      expect(body['needs'].pluck('key')).to eq(%w[handoff gap])
      expect(body['needs'].last).to include('question' => 'Do you ship to Spain?', 'count' => 1)
      expect(body['leads'].pluck('id')).to eq([conversation.display_id])
      expect(body['metrics']['product_answers']['value']).to eq(1)
      expect(body['project_status']).to eq('widget_installed' => true, 'mailbox_connected' => false, 'domain' => 'verified')
    end

    it 'shows a paused AI agent' do
      account.update!(subscription_settings: { enabled: true, trial_enabled: true, trial_ends_at: 1.day.ago })

      get url, headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body['status']).to eq('paused')
    end
  end

  describe 'usage' do
    it 'shows no limits when none are set in Super Admin' do
      get url, headers: admin.create_new_auth_token, as: :json

      usage = response.parsed_body['usage']
      expect(usage['ai_conversations']).to eq('used' => 0, 'limit' => nil, 'extra_left' => 0, 'forecast_date' => nil)
      expect(usage['agents']).to include('used' => 1, 'limit' => nil)
      expect(usage['plan']).to include('billing_enabled' => false, 'trial' => false, 'ai_replies_paused' => false)
    end

    it 'uses the Super Admin conversation limit, trial and account limits' do
      account.update!(limits: { 'agents' => 3, 'inboxes' => 2 },
                      subscription_settings: { enabled: true, monthly_limit: 50, trial_enabled: true, trial_days: 14 })

      get url, headers: admin.create_new_auth_token, as: :json

      usage = response.parsed_body['usage']
      expect(usage['ai_conversations']).to eq('used' => 0, 'limit' => 50, 'extra_left' => 0, 'forecast_date' => nil)
      expect(usage['agents']).to include('limit' => 3)
      expect(usage['inboxes']).to include('used' => 0, 'limit' => 2)
      expect(usage['plan']).to include('billing_enabled' => true, 'trial' => true, 'ai_replies_paused' => false)
      expect(usage['plan']['trial_ends_at']).to be_within(60).of(14.days.from_now.to_i)
    end

    it 'forecasts the day the limit is reached at the pace so far' do
      travel_to(Time.zone.parse('2026-11-12 12:00:00 UTC')) do
        account.update!(subscription_settings: { enabled: true, monthly_limit: 50, quota_anchor: 10.days.ago })
        subscription = account.subscription_settings
        inbox = create(:inbox, account: account)
        20.times do
          account.conversation_usage_windows.create!(conversation: create(:conversation, account: account, inbox: inbox),
                                                     started_at: 1.day.ago, ends_at: 1.day.from_now,
                                                     quota_period_start: subscription.quota_period.first)
        end

        get url, headers: admin.create_new_auth_token, as: :json

        # 20 in 10 days is 2 a day, so the 30 left last 15 days.
        expect(response.parsed_body['usage']['ai_conversations']).to include('used' => 20, 'forecast_date' => '2026-11-27')
      end
    end

    it 'reports paused AI replies after the trial ends' do
      account.update!(subscription_settings: { enabled: true, trial_enabled: true, trial_ends_at: 1.day.ago })

      get url, headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body['usage']['plan']).to include('trial' => true, 'ai_replies_paused' => true)
    end
  end
end
