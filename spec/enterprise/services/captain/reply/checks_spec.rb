require 'rails_helper'

RSpec.describe Captain::Reply::Checks do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:state) { {} }
  let(:run_result) { instance_double(Agents::RunResult, context: { state: state }) }
  let(:context) { Captain::Reply::Context.build(assistant: assistant, conversation: conversation, run_result: run_result) }
  let(:draft) { Captain::Reply::Draft.from_response({ 'response_parts' => [] }) }
  let(:welcome) { 'Hi there, welcome to Lumen Notes!' }
  let(:video) { '[Video](https://www.youtube.com/watch?v=lumen123abc)' }
  let(:log_suffix) { "assistant_id=#{assistant.id} conversation_id=#{conversation.id}" }

  def part(text, kind: :answer) = Captain::Reply::Part.new(text: text, kind: kind)

  def answer(text, parts: [part(text)], **attributes)
    Captain::Reply::Segment.new(kind: 'answer', text: text, parts: parts, content_type: 'text', additional_attributes: {}, **attributes)
  end

  def greeting = Captain::Reply::Segment.new(kind: 'greeting', text: welcome, parts: [part(welcome, kind: :greeting)], attach: :next)

  def repaired(*segments) = described_class.new(context, draft).repair(Captain::Reply::Plan.new(segments))

  before { allow(Rails.logger).to receive(:info) }

  describe 'single_greeting' do
    it 'drops the greeting when an earlier reply already greeted the customer' do
      conversation.messages.create!(message_type: :outgoing, account: account, inbox: inbox, sender: assistant, content: welcome,
                                    additional_attributes: { 'captain_segment_kinds' => %w[greeting answer] })

      plan = repaired(greeting, answer("#{welcome}\n\nSync runs every five minutes."))

      expect(plan.payloads(segment_kinds: false).pluck(:content)).to eq(['Sync runs every five minutes.'])
      expect(Rails.logger).to have_received(:info).with("[Captain][ReplyGuard] rule=single_greeting action=dropped_repeat #{log_suffix}")
    end

    it 'drops the greeting when the run says this is not the first reply' do
      state[:first_ai_reply] = false

      expect(repaired(greeting, answer("#{welcome}\n\nSync runs every five minutes.")).kinds).to eq(%w[answer])
    end

    it 'keeps one greeting per reply' do
      alone = greeting.with(attach: nil)

      expect(repaired(alone, alone.with(text: 'Hello again!')).segments.map(&:text)).to eq([welcome])
    end

    it 'keeps the greeting of a first reply' do
      expect(repaired(greeting, answer("#{welcome}\n\nSync runs every five minutes.")).kinds).to eq(%w[greeting answer])
      expect(Rails.logger).not_to have_received(:info).with(/ReplyGuard/)
    end
  end

  it 'shows each knowledge video once' do
    plan = repaired(answer("Sync keeps devices current.\n\n#{video}"), answer("Open Settings.\n\n#{video}"))

    expect(plan.segments.map(&:text)).to eq(["Sync keeps devices current.\n\n#{video}", 'Open Settings.'])
    expect(Rails.logger).to have_received(:info).with("[Captain][ReplyGuard] rule=media_once action=dropped #{log_suffix}")
  end

  describe 'no_repeated_sentences' do
    it 'drops the later copy of a sentence from the text and the stored parts' do
      plan = repaired(greeting,
                      answer("#{welcome}\n\n#{welcome} Sync runs every five minutes.", parts: [part("#{welcome} Sync runs every five minutes.")]))

      expect(plan.payloads(segment_kinds: false)).to eq(
        [{ content: "#{welcome}\n\nSync runs every five minutes.", content_type: 'text',
           additional_attributes: { 'captain_v2_response_parts' => [{ 'text' => welcome, 'citation_indexes' => [] },
                                                                    { 'text' => 'Sync runs every five minutes.', 'citation_indexes' => [] }] } }]
      )
    end

    it 'keeps short sentences and source lines' do
      sources = "Sync runs hourly.\n\n→ Sync your notes: https://docs.lumen-notes.test/sync"
      plan = repaired(answer("Yes. #{sources}"), answer("Yes. #{sources}"))

      expect(plan.segments.map(&:text)).to eq(["Yes. #{sources}"] * 2)
      expect(Rails.logger).not_to have_received(:info).with(/ReplyGuard/)
    end
  end

  it 'asks one closing question' do
    question = Captain::Reply::Segment.new(kind: 'question', text: 'Which plan are you on?')

    expect(repaired(answer('Pausing is free.'), question, question.with(text: 'Monthly or yearly?')).segments.map(&:text))
      .to eq(['Pausing is free.', 'Which plan are you on?'])
  end

  describe 'single_question with reworded questions' do
    let(:question) { Captain::Reply::Segment.new(kind: 'question', text: 'Which Mavic 3 version are you looking for?') }

    it 'takes a differently worded question out of the answer before the question bubble' do
      plan = repaired(answer('Yes, we carry the Mavic 3 Enterprise. Which one are you looking for?'), question)

      expect(plan.segments.map(&:text)).to eq(['Yes, we carry the Mavic 3 Enterprise.', 'Which Mavic 3 version are you looking for?'])
      expect(plan.segments.first.parts.map(&:text)).to eq(['Yes, we carry the Mavic 3 Enterprise.'])
      expect(Rails.logger).to have_received(:info).with("[Captain][ReplyGuard] rule=single_question action=stripped #{log_suffix}")
    end

    it 'keeps only the last of two answer bubbles that end with a question' do
      plan = repaired(answer('The Pro has 4K video. Do you film?'), answer('The Air folds small. Which matters more to you?'))

      expect(plan.segments.map(&:text)).to eq(['The Pro has 4K video.', 'The Air folds small. Which matters more to you?'])
    end

    it 'drops a bubble that only asked an earlier question' do
      plan = repaired(answer('Pausing is free.'), answer('Which plan are you on?'), question)

      expect(plan.segments.map(&:text)).to eq(['Pausing is free.', 'Which Mavic 3 version are you looking for?'])
    end

    it 'leaves questions inside the text alone' do
      plan = repaired(answer('Need more storage? The Pro plan has 1 TB.'), question)

      expect(plan.segments.first.text).to eq('Need more storage? The Pro plan has 1 TB.')
    end
  end

  it 'drops empty bubbles and lets a greeting attached to one stand alone' do
    buttons = Captain::Reply::Segment.new(kind: 'question', content_type: 'input_select', content_attributes: { items: [] })

    plan = repaired(greeting, answer(' ', parts: []), buttons)

    expect(plan.payloads(segment_kinds: false).pluck(:content)).to eq([welcome, nil])
    expect(Rails.logger).to have_received(:info).with("[Captain][ReplyGuard] rule=no_empty_segments action=dropped #{log_suffix}")
  end

  it 'joins answer bubbles beyond three into the third' do
    sources = ->(url) { { 'captain_sources' => [{ 'title' => url, 'url' => url }] } }
    bubbles = %w[One Two Three Four].map { |word| answer("#{word} sentence here.", content_attributes: sources.call("https://lumen-notes.test/#{word}")) }

    plan = repaired(*bubbles)

    expect(plan.segments.map(&:text)).to eq(['One sentence here.', 'Two sentence here.', "Three sentence here.\n\nFour sentence here."])
    expect(plan.segments.last.content_attributes['captain_sources'].pluck('url'))
      .to eq(%w[https://lumen-notes.test/Three https://lumen-notes.test/Four])
  end

  it 'logs the repeated welcome the draft removed and marks the trace' do
    span = instance_double(OpenTelemetry::Trace::Span, set_attribute: nil)
    allow(ChatwootApp).to receive(:otel_enabled?).and_return(true)
    allow(OpenTelemetry::Trace).to receive(:current_span).and_return(span)
    guarded = Captain::Reply::Draft.from_response({ 'welcome' => welcome,
                                                    'response_parts' => [{ 'text' => welcome }, { 'text' => 'Sync runs hourly.' }] })

    described_class.new(context, guarded).repair(Captain::Reply::Plan.new([answer('Sync runs hourly.')]))

    expect(Rails.logger).to have_received(:info).with("[Captain][ReplyGuard] rule=duplicate_welcome action=dropped #{log_suffix}").once
    expect(span).to have_received(:set_attribute).with('langfuse.observation.metadata.reply_guard_duplicate_welcome', 'dropped')
  end

  it 'logs a removed welcome once per reply although the chat job also asks whether the answer is empty' do
    response = { 'welcome' => welcome, 'response_parts' => [{ 'text' => welcome }, { 'text' => 'Sync runs hourly.' }] }
    composer = Captain::Conversation::ReplyComposer.new(assistant: assistant, conversation: conversation, response: response, run_result: run_result)

    composer.empty_response?
    composer.messages

    expect(Rails.logger).to have_received(:info).with(/rule=duplicate_welcome/).once
  end
end
