require 'rails_helper'

RSpec.describe Captain::KnowledgeGaps::Classification do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:chat) { instance_double(RubyLLM::Chat) }
  let(:embedder) { instance_double(Captain::Llm::EmbeddingService) }
  # The model's reply per customer message (classification) or per rewritten question (draft answer).
  let(:outputs) { {} }
  # One axis per meaning: same axis = same question, another axis = cosine distance 1.
  let(:axes) { {} }

  before do
    allow(Captain::Assistant::TieredLlmClient).to receive(:chat).and_return(chat)
    allow(chat).to receive_messages(with_params: chat, with_instructions: chat)
    allow(chat).to receive(:ask) do |input|
      payload = JSON.parse(input)
      instance_double(RubyLLM::Message, content: outputs.fetch(payload['message'] || payload['question']).to_json)
    end
    allow(Captain::Llm::EmbeddingService).to receive(:new).and_return(embedder)
    allow(embedder).to receive(:get_embedding) do |text|
      Array.new(1536, 0.0).tap do |vector|
        vector[axes.fetch(text)] = 1.0
        vector[1535] = 0.05
      end
    end
  end

  def record(message, reason: 'no_source', conversation: create(:conversation, account: account, inbox: inbox))
    Captain::KnowledgeGaps::Recorder.new(assistant: assistant, conversation: conversation, question: message, reason: reason,
                                         message_id: conversation.messages.incoming.last&.id).record
  end

  def classify(message, **)
    described_class.new(record(message, **)).perform
  end

  describe 'the two ticket examples' do
    let(:generator_message) do
      "I have a dji t50 and the generator I bought doesn't keep up, want to make sure the generator you are selling will"
    end

    before do
      outputs[generator_message] = { kind: 'knowledge', canonical_question: 'Can your generator power a DJI T50?',
                                     topic: 'Generator compatibility', language: 'en', intent: nil }
      outputs['can you check where is my order'] = { kind: 'action_request', canonical_question: 'Where is my order?',
                                                     topic: 'Order status', language: 'en', intent: 'order_status' }
      axes.merge!('Can your generator power a DJI T50?' => 0, 'Where is my order?' => 1)
    end

    it 'rewrites the generator message into a general knowledge question and keeps the raw text as an example' do
      gap = classify(generator_message, reason: 'handoff')

      expect(gap).to have_attributes(kind: 'knowledge', question: 'Can your generator power a DJI T50?',
                                     topic: 'Generator compatibility', language: 'en', intent: nil)
      expect(gap.occurrences.pluck(:question)).to eq([generator_message])
      expect(assistant.knowledge_gaps.unanswered).to eq([gap])
    end

    it 'counts the order question as an order status request, not as an unanswered question' do
      gap = classify('can you check where is my order', reason: 'handoff')

      expect(gap).to have_attributes(kind: 'action_request', intent: 'order_status', question: 'Where is my order?')
      expect(assistant.knowledge_gaps.unanswered).to be_empty
    end

    it 'sends the messages before the question as context' do
      conversation = create(:conversation, account: account, inbox: inbox)
      create(:message, conversation: conversation, account: account, message_type: :incoming, content: 'Looking at your 12kW generator')
      create(:message, conversation: conversation, account: account, message_type: :outgoing, content: 'Happy to help!')
      create(:message, conversation: conversation, account: account, message_type: :outgoing, private: true, content: 'internal note')
      create(:message, conversation: conversation, account: account, message_type: :incoming, content: generator_message)

      classify(generator_message, conversation: conversation)

      expect(chat).to have_received(:ask).with(satisfy do |input|
        JSON.parse(input)['earlier_messages'] == [{ 'role' => 'customer', 'text' => 'Looking at your 12kW generator' },
                                                  { 'role' => 'store', 'text' => 'Happy to help!' }]
      end)
    end

    it 'never counts as AI usage' do
      allow(ChatwootApp).to receive(:chatwoot_cloud?).and_return(true)
      account.update!(custom_attributes: { 'captain_responses_usage' => 3 })

      expect do
        classify(generator_message, reason: 'handoff')
        classify('can you check where is my order')
      end.not_to change(ConversationUsageWindow, :count)
      expect(account.reload.custom_attributes['captain_responses_usage']).to eq(3)
    end
  end

  describe 'merging' do
    before do
      outputs['do you ship to spain'] = { kind: 'knowledge', canonical_question: 'Do you ship to Spain?', topic: 'Shipping' }
      outputs['Can I get delivery to Madrid?'] = { kind: 'knowledge', canonical_question: 'Do you deliver to Spain?', topic: 'Shipping' }
      outputs['do you ship to france'] = { kind: 'knowledge', canonical_question: 'Do you ship to France?', topic: 'Shipping' }
      axes.merge!('Do you ship to Spain?' => 0, 'Do you deliver to Spain?' => 0, 'Do you ship to France?' => 2)
    end

    it 'merges a paraphrase into the existing gap and keeps its question' do
      spain = classify('do you ship to spain')
      merged = classify('Can I get delivery to Madrid?')

      expect(merged).to eq(spain)
      expect(spain.reload).to have_attributes(question: 'Do you ship to Spain?', occurrences_count: 2)
      expect(spain.occurrences.pluck(:question)).to contain_exactly('do you ship to spain', 'Can I get delivery to Madrid?')
      expect(assistant.knowledge_gaps.count).to eq(1)
    end

    it 'keeps a different question apart' do
      classify('do you ship to spain')
      classify('do you ship to france')

      expect(assistant.knowledge_gaps.pluck(:question)).to contain_exactly('Do you ship to Spain?', 'Do you ship to France?')
    end

    it 'counts a conversation once after the merge' do
      conversation = create(:conversation, account: account, inbox: inbox)
      spain = classify('do you ship to spain', conversation: conversation)
      classify('Can I get delivery to Madrid?', conversation: conversation)

      expect(spain.reload.occurrences_count).to eq(1)
    end

    it 'reopens an answered gap and keeps a dismissed gap dismissed' do
      classify('do you ship to spain').answered!
      expect(classify('Can I get delivery to Madrid?')).to be_open

      assistant.knowledge_gaps.first.dismissed!
      outputs['delivery to spain?'] = outputs['Can I get delivery to Madrid?']
      expect(classify('delivery to spain?')).to be_dismissed
    end

    it 'sends a later message with a text seen before straight to the merged gap' do
      spain = classify('do you ship to spain')
      classify('Can I get delivery to Madrid?')

      expect { record('can i get delivery to madrid') }.not_to have_enqueued_job(Captain::KnowledgeGaps::ClassifyJob)
      expect(spain.reload.occurrences_count).to eq(3)
    end

    it 'does not merge action requests with different intents' do
      outputs['cancel my order'] = { kind: 'action_request', canonical_question: 'Cancel my order', intent: 'cancel' }
      outputs['return my order'] = { kind: 'action_request', canonical_question: 'Return my order', intent: 'return' }
      axes.merge!('Cancel my order' => 3, 'Return my order' => 3)

      classify('cancel my order')
      classify('return my order')

      expect(assistant.knowledge_gaps.pluck(:intent)).to contain_exactly('cancel', 'return')
    end

    it 'merges only the same rewritten question when the embedding fails' do
      allow(embedder).to receive(:get_embedding).and_raise(Captain::Llm::EmbeddingService::EmbeddingsError)
      outputs['spain shipping?'] = outputs['do you ship to spain']

      spain = classify('do you ship to spain')
      expect(classify('spain shipping?')).to eq(spain)
      expect(classify('Can I get delivery to Madrid?')).not_to eq(spain)
    end
  end

  describe 'draft answer' do
    let(:conversation) { create(:conversation, account: account, inbox: inbox) }
    let(:agent) { create(:user, account: account) }

    before do
      outputs['do you ship to spain'] = { kind: 'knowledge', canonical_question: 'Do you ship to Spain?', topic: 'Shipping' }
      axes['Do you ship to Spain?'] = 0
      create(:message, conversation: conversation, account: account, message_type: :incoming, content: 'do you ship to spain')
    end

    it 'stores a general answer from what a person replied after the question' do
      create(:message, conversation: conversation, account: account, message_type: :outgoing, sender: agent,
                       content: 'Hi Jan, yes we ship to Spain, delivery takes 3 days.')
      outputs['Do you ship to Spain?'] = { draft_answer: 'Yes, we ship to Spain. Delivery takes about 3 days.' }

      gap = classify('do you ship to spain', conversation: conversation)

      expect(gap.draft_answer).to eq('Yes, we ship to Spain. Delivery takes about 3 days.')
      expect(chat).to have_received(:ask).with(include('Hi Jan, yes we ship to Spain'))
    end

    it 'stores nothing when the reply does not answer the question' do
      create(:message, conversation: conversation, account: account, message_type: :outgoing, sender: agent, content: 'Let me check.')
      outputs['Do you ship to Spain?'] = { draft_answer: nil }

      expect(classify('do you ship to spain', conversation: conversation).draft_answer).to be_nil
    end

    it 'does not ask the model without a reply from a person' do
      create(:message, conversation: conversation, account: account, message_type: :outgoing, sender: assistant, content: 'AI reply')

      classify('do you ship to spain', conversation: conversation)

      expect(chat).to have_received(:ask).once
    end
  end

  it 'raises on output it cannot use, so the job retries' do
    outputs['hm'] = { kind: 'question', canonical_question: 'Hm?' }

    expect { classify('hm') }.to raise_error(Captain::KnowledgeGaps::Classifier::InvalidOutput)
    expect(assistant.knowledge_gaps.first).to be_unclassified
  end
end
