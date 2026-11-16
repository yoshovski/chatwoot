require 'rails_helper'

RSpec.describe Captain::HomeActivityBuilder do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }

  around { |example| travel_to(Time.zone.parse('2026-11-12 12:00:00 UTC')) { example.run } }

  def ai_reply(conversation, at)
    create(:message, account: account, inbox: inbox, conversation: conversation, sender: assistant,
                     message_type: :outgoing, created_at: at)
  end

  it 'returns zeros, an empty rating and no topics for a new account' do
    activity = described_class.new(account, period: 7).activity

    expect(activity[:period]).to eq(7)
    expect(activity[:metrics][:ai_conversations]).to eq(value: 0, previous: 0, points: [0] * 7)
    expect(activity[:metrics][:resolved]).to eq(value: 0, previous: 0, points: [0] * 7)
    expect(activity[:metrics][:rating]).to eq(value: nil, previous: nil, points: [nil] * 7)
    expect(activity[:days].pluck(:date)).to eq(%w[2026-11-06 2026-11-07 2026-11-08 2026-11-09 2026-11-10 2026-11-11 2026-11-12])
    expect(activity[:topics]).to eq([])
  end

  it 'has one point per day for 30 days' do
    activity = described_class.new(account, period: 30).activity

    expect(activity[:metrics][:handed][:points].size).to eq(30)
    expect(activity[:days].first[:date]).to eq('2026-10-14')
  end

  describe 'with conversations' do
    let(:today_conversation) { create(:conversation, account: account, inbox: inbox) }
    let(:yesterday_conversation) { create(:conversation, account: account, inbox: inbox) }
    let(:earlier_conversation) { create(:conversation, account: account, inbox: inbox) }

    before do
      ai_reply(today_conversation, 1.hour.ago)
      ai_reply(today_conversation, 30.minutes.ago)
      ai_reply(yesterday_conversation, 1.day.ago)
      ai_reply(earlier_conversation, 10.days.ago)
      create(:message, account: account, inbox: inbox, conversation: today_conversation, sender: agent,
                       message_type: :outgoing, created_at: 10.minutes.ago)
      create(:message, account: account, inbox: inbox, conversation: yesterday_conversation, sender: agent,
                       message_type: :outgoing, private: true, created_at: 1.day.ago)
    end

    it 'counts each conversation once per period, compared with the period before' do
      metric = described_class.new(account, period: 7).activity[:metrics][:ai_conversations]

      expect(metric).to eq(value: 2, previous: 1, points: [0, 0, 0, 0, 0, 1, 1])
    end

    it 'splits each day into the AI agent and public replies from the team' do
      days = described_class.new(account, period: 7).activity[:days]

      expect(days.last(2)).to eq([{ date: '2026-11-11', ai: 1, team: 0 }, { date: '2026-11-12', ai: 1, team: 1 }])
    end

    it 'derives the solved share and handoffs from reporting events' do
      create(:reporting_event, account: account, conversation: today_conversation, name: 'conversation_captain_inference_resolved',
                               created_at: 20.minutes.ago)
      create(:reporting_event, account: account, conversation: yesterday_conversation, name: 'conversation_bot_handoff',
                               created_at: 1.day.ago)
      create(:reporting_event, account: account, conversation: yesterday_conversation, name: 'conversation_bot_resolved',
                               created_at: 1.day.ago)

      metrics = described_class.new(account, period: 7).activity[:metrics]

      expect(metrics[:resolved]).to eq(value: 50, previous: 0, points: [0, 0, 0, 0, 0, 0, 100])
      expect(metrics[:handed]).to eq(value: 1, previous: 0, points: [0, 0, 0, 0, 0, 1, 0])
    end

    it 'averages customer ratings per period and per day' do
      [4, 5].each { |rating| create(:csat_survey_response, account: account, conversation: today_conversation, rating: rating) }
      create(:csat_survey_response, account: account, conversation: earlier_conversation, rating: 2, created_at: 9.days.ago)

      rating = described_class.new(account, period: 7).activity[:metrics][:rating]

      expect(rating).to eq(value: 4.5, previous: 2.0, points: [nil, nil, nil, nil, nil, nil, 4.5])
    end

    it 'counts conversations answered from a product' do
      Captain::AgentSession.create!(assistant: assistant, session_type: :assistant, subject: today_conversation,
                                    sources: [{ index: 1, reference: 'product:mug', kind: 'product', used: true }])
      Captain::AgentSession.create!(assistant: assistant, session_type: :assistant, subject: yesterday_conversation,
                                    sources: [{ index: 1, reference: 'doc:faq', kind: 'document', used: true }])

      metric = described_class.new(account, period: 7).activity[:metrics][:product_answers]

      expect(metric).to eq(value: 1, previous: 0, points: [0, 0, 0, 0, 0, 0, 1])
    end

    it 'lists the most used labels of the period as topics' do
      today_conversation.update!(label_list: %w[shipping sizing])
      yesterday_conversation.update!(label_list: %w[shipping])

      expect(described_class.new(account, period: 7).activity[:topics]).to eq([{ label: 'shipping', count: 2 }, { label: 'sizing', count: 1 }])
    end
  end

  it "puts a reply on the viewer's calendar day" do
    ai_reply(create(:conversation, account: account, inbox: inbox), Time.zone.parse('2026-11-11 23:30:00 UTC'))

    utc = described_class.new(account, period: 7).activity[:metrics][:ai_conversations][:points]
    madrid = described_class.new(account, period: 7, timezone_offset: '1').activity[:metrics][:ai_conversations][:points]

    expect(utc.last(2)).to eq([1, 0])
    expect(madrid.last(2)).to eq([0, 1])
  end

  describe 'workspace analytics ranges' do
    it 'counts both assistants while per-assistant metrics remain scoped' do
      other = create(:captain_assistant, account: account)
      first_conversation = create(:conversation, account: account, inbox: inbox)
      second_conversation = create(:conversation, account: account, inbox: inbox)
      ai_reply(first_conversation, 60.days.ago)
      create(:message, account: account, inbox: inbox, conversation: second_conversation,
                       sender: other, message_type: :outgoing, created_at: 1.day.ago)

      workspace = described_class.new(account, period: 7, range: '90').activity
      selected = Captain::AssistantStatsBuilder.new(assistant, '90').metrics
      expect(workspace[:metrics][:ai_conversations][:value]).to eq(2)
      expect(selected[:conversations_handled][:current]).to eq(1)
      expect(workspace[:days].first[:date]).to eq(90.days.ago.to_date.iso8601)
    end

    it 'partitions ratings at the exact rolling boundary even on the same date' do
      conversation = create(:conversation, account: account, inbox: inbox)
      create(:csat_survey_response, account: account, conversation: conversation, rating: 1, created_at: 7.days.ago - 1.hour)
      create(:csat_survey_response, account: account, conversation: conversation, rating: 5, created_at: 7.days.ago + 1.hour)

      rating = described_class.new(account, period: 7, range: '7').activity[:metrics][:rating]
      expect(rating[:value]).to eq(5)
      expect(rating[:previous]).to eq(1)
      expect(rating[:points].first).to eq(5)
    end

    it 'excludes the unused remainder of the prior month from month-to-date ratings' do
      conversation = create(:conversation, account: account, inbox: inbox)
      create(:csat_survey_response, account: account, conversation: conversation, rating: 1, created_at: Time.zone.parse('2026-10-30 12:00'))
      create(:csat_survey_response, account: account, conversation: conversation, rating: 2, created_at: Time.zone.parse('2026-10-05 12:00'))
      create(:csat_survey_response, account: account, conversation: conversation, rating: 5, created_at: Time.zone.parse('2026-11-05 12:00'))

      rating = described_class.new(account, period: 7, range: 'this_month').activity[:metrics][:rating]
      expect(rating[:value]).to eq(5)
      expect(rating[:previous]).to eq(2)
    end

    it 'uses completed calendar months and the viewer timezone' do
      activity = described_class.new(account, period: 7, range: 'last_month', timezone_offset: '1').activity
      expect(activity[:days].first[:date]).to eq('2026-10-01')
      expect(activity[:days].last[:date]).to eq('2026-10-31')
    end
  end
end
