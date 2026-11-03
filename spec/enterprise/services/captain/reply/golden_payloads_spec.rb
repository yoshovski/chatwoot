# frozen_string_literal: true

require 'rails_helper'

# The message payloads one Captain V2 reply turns into, frozen from the composer before the reply plan refactor
# (CWAI-143). A change here is a change in what customers see.
RSpec.describe 'Captain reply golden payloads' do # rubocop:disable RSpec/DescribeClass
  let(:account) { create(:account) }
  let(:assistant) do
    create(:captain_assistant, account: account,
                               config: { 'suggested_replies' => true, 'max_suggested_replies' => 3, 'product_cards' => true,
                                         'image_allowlist' => ['https://cdn.shopify.com/'] })
  end
  let(:channels) do
    { widget: -> { create(:channel_widget, account: account) }, email: -> { create(:channel_email, account: account) },
      sms: -> { create(:channel_sms, account: account) } }
  end
  let(:citation_urls) { { 1 => 'https://docs.lumen-notes.test/sync', 2 => 'https://docs.lumen-notes.test/teams' } }
  let(:citation_titles) { { 1 => 'Sync your notes', 2 => 'Team spaces' } }
  let(:product_cache) do
    { 'trail-boot' => { 'handle' => 'trail-boot', 'title' => 'Trail Boot', 'image_url' => 'https://cdn.shopify.com/boot.jpg',
                        'product_url' => 'https://acme-outdoor.test/products/trail-boot',
                        'variants' => [{ 'price' => '129.00', 'currency' => 'EUR' }] } }
  end
  let(:video) { '[Video](https://www.youtube.com/watch?v=lumen123abc)' }
  let(:screenshot) { '[Screenshot: Sync settings](https://docs.lumen-notes.test/sync.png)' }
  let(:steps) { "To turn on sync:\n\n1. Open Settings.\n2. Choose Sync." }
  # Symbols in the table stand for these values.
  let(:placeholders) do
    { steps: steps, steps_with_media: "#{steps}\n\n#{video}\n\n#{screenshot}", assistant_agent_name: assistant.agent_name }
  end

  cases = {
    plain_answer: {
      response: { 'agent_name' => 'Lumen', 'response_parts' => [{ 'text' => 'Sync runs every five minutes.', 'citation_indexes' => [] }],
                  'suggested_replies' => ['Sync now', 'Offline mode'] },
      expected: [{ content: 'Sync runs every five minutes.',
                   content_type: 'input_select',
                   additional_attributes: { :agent_name => 'Lumen',
                                            'captain_v2_response_parts' => [{ 'text' => 'Sync runs every five minutes.',
                                                                              'citation_indexes' => [] }] },
                   content_attributes: { items: [{ 'title' => 'Sync now', 'value' => 'Sync now' },
                                                 { 'title' => 'Offline mode', 'value' => 'Offline mode' }],
                                         submit_value: true } }]
    },
    trailing_question_widget: {
      response: { 'agent_name' => 'Lumen',
                  'response_parts' => [{ 'text' => 'You can pause a plan for up to three months. Which plan are you on?',
                                         'citation_indexes' => [] }],
                  'suggested_replies' => [{ 'label' => 'Monthly', 'message' => 'I am on the monthly plan.' }] },
      expected: [{ content: 'You can pause a plan for up to three months.',
                   content_type: 'text',
                   additional_attributes: { :agent_name => 'Lumen',
                                            'captain_v2_response_parts' => [{ 'text' => 'You can pause a plan for up to three months.',
                                                                              'citation_indexes' => [] }] } },
                 { content: 'Which plan are you on?',
                   additional_attributes: { agent_name: 'Lumen' },
                   content_type: 'input_select',
                   content_attributes: { items: [{ 'title' => 'Monthly', 'value' => 'I am on the monthly plan.' }], submit_value: true } }]
    },
    trailing_question_email: {
      channel: :email,
      response: { 'response_parts' => [{ 'text' => 'You can pause a plan for up to three months. Which plan are you on?',
                                         'citation_indexes' => [] }],
                  'suggested_replies' => ['Monthly'] },
      expected: [{ content: 'You can pause a plan for up to three months. Which plan are you on?',
                   content_type: 'input_select',
                   additional_attributes: { 'captain_v2_response_parts' => [{ 'text' =>
                                                                                'You can pause a plan for up to three months. Which plan are you on?',
                                                                              'citation_indexes' => [] }] },
                   content_attributes: { items: [{ 'title' => 'Monthly', 'value' => 'Monthly' }], submit_value: true } }]
    },
    trailing_question_sms: {
      channel: :sms,
      response: { 'response_parts' => [{ 'text' => 'You can pause a plan for up to three months. Which plan are you on?',
                                         'citation_indexes' => [] }],
                  'suggested_replies' => ['Monthly'] },
      expected: [{ content: 'You can pause a plan for up to three months. Which plan are you on?',
                   content_type: 'input_select',
                   additional_attributes: { 'captain_v2_response_parts' => [{ 'text' =>
                                                                                'You can pause a plan for up to three months. Which plan are you on?',
                                                                              'citation_indexes' => [] }] },
                   content_attributes: { items: [{ 'title' => 'Monthly', 'value' => 'Monthly' }], submit_value: true } }]
    },
    short_greeting_with_question: {
      response: { 'response_parts' => [{ 'text' => 'Hi there! How can I help?', 'citation_indexes' => [] }] },
      expected: [{ content: 'Hi there! How can I help?',
                   content_type: 'text',
                   additional_attributes: { 'captain_v2_response_parts' => [{ 'text' => 'Hi there! How can I help?', 'citation_indexes' => [] }] } }]
    },
    qualification_question: {
      response: { 'agent_name' => 'Lumen', 'lead_qualification_question' => true,
                  'response_parts' => [{ 'text' => 'Team spaces suit groups. How large is your team?', 'citation_indexes' => [] },
                                       { 'text' => 'Exports work on every plan.', 'citation_indexes' => [] }],
                  'suggested_replies' => ['Under 10'] },
      expected: [{ content: "Team spaces suit groups.\n\nExports work on every plan.",
                   content_type: 'text',
                   additional_attributes: { :agent_name => 'Lumen',
                                            'business_lead_question' => true,
                                            'captain_v2_response_parts' => [{ 'text' => 'Team spaces suit groups.', 'citation_indexes' => [] },
                                                                            { 'text' => 'Exports work on every plan.',
                                                                              'citation_indexes' => [] }] } },
                 { content: 'How large is your team?',
                   additional_attributes: { agent_name: 'Lumen' },
                   content_type: 'input_select',
                   content_attributes: { items: [{ 'title' => 'Under 10', 'value' => 'Under 10' }], submit_value: true } }]
    },
    separate_parts: {
      citations: true,
      response: { 'response_parts' => [{ 'text' => 'Our trial lasts 14 days.', 'citation_indexes' => [1] },
                                       { 'text' => 'You can add teammates at any time.', 'citation_indexes' => [2] },
                                       { 'text' => 'Exports work on every plan.', 'citation_indexes' => [] },
                                       { 'text' => 'How large is your team?', 'citation_indexes' => [] }],
                  'separate_parts' => [3, 1, 2, 9], 'suggested_replies' => ['Under 10'] },
      expected: [{ content: 'Our trial lasts 14 days.',
                   content_type: 'text',
                   additional_attributes: { 'captain_v2_response_parts' => [{ 'text' => 'Our trial lasts 14 days.', 'citation_indexes' => [1] }] },
                   content_attributes: { 'captain_sources' => [{ 'title' => 'Sync your notes', 'url' => 'https://docs.lumen-notes.test/sync' }] } },
                 { content: 'You can add teammates at any time.',
                   content_type: 'text',
                   additional_attributes: { 'captain_v2_response_parts' => [{ 'text' => 'You can add teammates at any time.',
                                                                              'citation_indexes' => [2] }] },
                   content_attributes: { 'captain_sources' => [{ 'title' => 'Team spaces', 'url' => 'https://docs.lumen-notes.test/teams' }] } },
                 { content: 'Exports work on every plan.',
                   content_type: 'text',
                   additional_attributes: { 'captain_v2_response_parts' => [{ 'text' => 'Exports work on every plan.',
                                                                              'citation_indexes' => [] }] } },
                 { content: 'How large is your team?',
                   additional_attributes: {},
                   content_type: 'input_select',
                   content_attributes: { items: [{ 'title' => 'Under 10', 'value' => 'Under 10' }], submit_value: true } }]
    },
    separate_parts_with_welcome: {
      citations: true,
      response: { 'welcome' => 'Hi there, thanks for asking!',
                  'response_parts' => [{ 'text' => 'Our trial lasts 14 days.', 'citation_indexes' => [1] },
                                       { 'text' => 'You can add teammates at any time.', 'citation_indexes' => [2] },
                                       { 'text' => 'How large is your team?', 'citation_indexes' => [] }],
                  'separate_parts' => [1] },
      expected: [{ content: "Hi there, thanks for asking!\n\nOur trial lasts 14 days.",
                   content_type: 'text',
                   additional_attributes: { 'captain_v2_response_parts' => [{ 'text' => 'Hi there, thanks for asking!', 'citation_indexes' => [] },
                                                                            { 'text' => 'Our trial lasts 14 days.', 'citation_indexes' => [1] }] },
                   content_attributes: { 'captain_sources' => [{ 'title' => 'Sync your notes', 'url' => 'https://docs.lumen-notes.test/sync' }] } },
                 { content: 'You can add teammates at any time.',
                   content_type: 'text',
                   additional_attributes: { 'captain_v2_response_parts' => [{ 'text' => 'You can add teammates at any time.',
                                                                              'citation_indexes' => [2] }] },
                   content_attributes: { 'captain_sources' => [{ 'title' => 'Team spaces', 'url' => 'https://docs.lumen-notes.test/teams' }] } },
                 { content: 'How large is your team?', additional_attributes: {} }]
    },
    separate_parts_welcome_alone: {
      response: { 'welcome' => 'Hi there, thanks for asking!',
                  'response_parts' => [{ 'text' => 'Our trial lasts 14 days.', 'citation_indexes' => [] },
                                       { 'text' => 'You can add teammates at any time.', 'citation_indexes' => [] }],
                  'separate_parts' => [0, 1] },
      expected: [{ content: 'Hi there, thanks for asking!',
                   content_type: 'text',
                   additional_attributes:
                   { 'captain_v2_response_parts' => [{ 'text' => 'Hi there, thanks for asking!', 'citation_indexes' => [] }] } },
                 { content: 'Our trial lasts 14 days.',
                   content_type: 'text',
                   additional_attributes: { 'captain_v2_response_parts' => [{ 'text' => 'Our trial lasts 14 days.', 'citation_indexes' => [] }] } },
                 { content: 'You can add teammates at any time.',
                   content_type: 'text',
                   additional_attributes: { 'captain_v2_response_parts' => [{ 'text' => 'You can add teammates at any time.',
                                                                              'citation_indexes' => [] }] } }]
    },
    separate_parts_email: {
      channel: :email,
      response: { 'response_parts' => [{ 'text' => 'Our trial lasts 14 days.', 'citation_indexes' => [] },
                                       { 'text' => 'You can add teammates at any time.', 'citation_indexes' => [] }],
                  'separate_parts' => [1] },
      expected: [{ content: "Our trial lasts 14 days.\n\nYou can add teammates at any time.",
                   content_type: 'text',
                   additional_attributes: { 'captain_v2_response_parts' => [{ 'text' => 'Our trial lasts 14 days.', 'citation_indexes' => [] },
                                                                            { 'text' => 'You can add teammates at any time.',
                                                                              'citation_indexes' => [] }] } }]
    },
    welcome: {
      response: { 'welcome' => 'Hi there, welcome to Lumen Notes!',
                  'response_parts' => [{ 'text' => 'Sync runs every five minutes.', 'citation_indexes' => [] }],
                  'suggested_replies' => ['Sync now'] },
      expected: [{ content: "Hi there, welcome to Lumen Notes!\n\nSync runs every five minutes.",
                   content_type: 'input_select',
                   additional_attributes: { 'captain_v2_response_parts' => [{ 'text' => 'Hi there, welcome to Lumen Notes!',
                                                                              'citation_indexes' => [] },
                                                                            { 'text' => 'Sync runs every five minutes.',
                                                                              'citation_indexes' => [] }] },
                   content_attributes: { items: [{ 'title' => 'Sync now', 'value' => 'Sync now' }], submit_value: true } }]
    },
    welcome_repeated_exactly: {
      response: { 'welcome' => 'Hi there, welcome to Lumen Notes!',
                  'response_parts' => [{ 'text' => 'Hi there, welcome to Lumen Notes!', 'citation_indexes' => [1] },
                                       { 'text' => 'Sync runs every five minutes.', 'citation_indexes' => [] },
                                       { 'text' => 'Offline notes sync when you reconnect.', 'citation_indexes' => [] }],
                  'separate_parts' => [2] },
      expected: [{ content: "Hi there, welcome to Lumen Notes!\n\nSync runs every five minutes.",
                   content_type: 'text',
                   additional_attributes: { 'captain_v2_response_parts' => [{ 'text' => 'Hi there, welcome to Lumen Notes!',
                                                                              'citation_indexes' => [] },
                                                                            { 'text' => 'Sync runs every five minutes.',
                                                                              'citation_indexes' => [1] }] } },
                 { content: 'Offline notes sync when you reconnect.',
                   content_type: 'text',
                   additional_attributes: { 'captain_v2_response_parts' => [{ 'text' => 'Offline notes sync when you reconnect.',
                                                                              'citation_indexes' => [] }] } }]
    },
    welcome_repeated_as_prefix: {
      response: { 'welcome' => 'Hi there, welcome to Lumen Notes!',
                  'response_parts' => [{ 'text' => 'Hi there, welcome to Lumen Notes! 😊 Sync runs every five minutes.',
                                         'citation_indexes' => [] },
                                       { 'text' => 'Offline notes sync when you reconnect.', 'citation_indexes' => [] }],
                  'separate_parts' => [1] },
      expected: [{ content: "Hi there, welcome to Lumen Notes!\n\nSync runs every five minutes.",
                   content_type: 'text',
                   additional_attributes: { 'captain_v2_response_parts' => [{ 'text' => 'Hi there, welcome to Lumen Notes!',
                                                                              'citation_indexes' => [] },
                                                                            { 'text' => 'Sync runs every five minutes.',
                                                                              'citation_indexes' => [] }] } },
                 { content: 'Offline notes sync when you reconnect.',
                   content_type: 'text',
                   additional_attributes: { 'captain_v2_response_parts' => [{ 'text' => 'Offline notes sync when you reconnect.',
                                                                              'citation_indexes' => [] }] } }]
    },
    welcome_repeated_as_greeting: {
      response: { 'welcome' => 'Hi there, welcome to Lumen Notes!',
                  'response_parts' => [{ 'text' => 'Hello and welcome! Sync runs every five minutes.', 'citation_indexes' => [] }] },
      expected: [{ content: "Hi there, welcome to Lumen Notes!\n\nSync runs every five minutes.",
                   content_type: 'text',
                   additional_attributes: { 'captain_v2_response_parts' => [{ 'text' => 'Hi there, welcome to Lumen Notes!',
                                                                              'citation_indexes' => [] },
                                                                            { 'text' => 'Sync runs every five minutes.',
                                                                              'citation_indexes' => [] }] } }]
    },
    welcome_is_the_whole_answer: {
      response: { 'welcome' => 'Hi there, welcome to Lumen Notes!',
                  'response_parts' => [{ 'text' => 'Hi there, welcome to Lumen Notes!', 'citation_indexes' => [] }] },
      expected: [{ content: "Hi there, welcome to Lumen Notes!\n\nHi there, welcome to Lumen Notes!",
                   content_type: 'text',
                   additional_attributes: { 'captain_v2_response_parts' => [{ 'text' => 'Hi there, welcome to Lumen Notes!',
                                                                              'citation_indexes' => [] },
                                                                            { 'text' => 'Hi there, welcome to Lumen Notes!',
                                                                              'citation_indexes' => [] }] } }]
    },
    sources_structured: {
      citations: true,
      response: { 'response_parts' => [{ 'text' => 'Sync runs every five minutes.', 'citation_indexes' => [1] }],
                  'suggested_replies' => ['Sync now'] },
      expected: [{ content: 'Sync runs every five minutes.',
                   content_type: 'input_select',
                   additional_attributes: { 'captain_v2_response_parts' =>
                                              [{ 'text' => 'Sync runs every five minutes.', 'citation_indexes' => [1] }] },
                   content_attributes: { :items => [{ 'title' => 'Sync now', 'value' => 'Sync now' }],
                                         :submit_value => true,
                                         'captain_sources' => [{ 'title' => 'Sync your notes', 'url' => 'https://docs.lumen-notes.test/sync' }] } }]
    },
    sources_off: {
      stub_citations: true,
      response: { 'response_parts' => [{ 'text' => 'Sync runs every five minutes.', 'citation_indexes' => [1] }] },
      expected: [{ content: 'Sync runs every five minutes.',
                   content_type: 'text',
                   additional_attributes: { 'captain_v2_response_parts' =>
                                              [{ 'text' => 'Sync runs every five minutes.', 'citation_indexes' => [1] }] } }]
    },
    sources_email: {
      channel: :email, citations: true,
      response: { 'response_parts' => [{ 'text' => 'Sync runs every five minutes.', 'citation_indexes' => [1, 2] }] },
      expected: [{ content:
                   "Sync runs every five minutes.\n\n→ [Sync your notes](https://docs.lumen-notes.test/sync)\n→ [Team spaces](https://docs.lumen-notes.test/teams)",
                   content_type: 'text',
                   additional_attributes: { 'captain_v2_response_parts' => [{ 'text' => 'Sync runs every five minutes.',
                                                                              'citation_indexes' => [1, 2] }] } }]
    },
    sources_sms: {
      channel: :sms, citations: true,
      response: { 'response_parts' => [{ 'text' => 'Sync runs every five minutes.', 'citation_indexes' => [1] }] },
      expected: [{ content: "Sync runs every five minutes.\n\n→ Sync your notes: https://docs.lumen-notes.test/sync",
                   content_type: 'text',
                   additional_attributes: { 'captain_v2_response_parts' =>
                                              [{ 'text' => 'Sync runs every five minutes.', 'citation_indexes' => [1] }] } }]
    },
    knowledge_video_and_screenshots: {
      stub_citations: true,
      state: :knowledge_media,
      response: { 'response_parts' => [{ 'text' => :steps, 'citation_indexes' => [1] }], 'suggested_replies' => ['Sync now'] },
      expected: [{ content:
                   :steps_with_media,
                   content_type: 'input_select',
                   additional_attributes: { 'captain_v2_response_parts' => [{ 'text' => :steps,
                                                                              'citation_indexes' => [1] }] },
                   content_attributes: { items: [{ 'title' => 'Sync now', 'value' => 'Sync now' }], submit_value: true } }]
    },
    knowledge_media_split: {
      stub_citations: true,
      state: :knowledge_media,
      response: { 'response_parts' => [{ 'text' => 'Sync keeps every device current.', 'citation_indexes' => [] },
                                       { 'text' => :steps, 'citation_indexes' => [1] }],
                  'separate_parts' => [1] },
      expected: [{ content: 'Sync keeps every device current.',
                   content_type: 'text',
                   additional_attributes: { 'captain_v2_response_parts' => [{ 'text' => 'Sync keeps every device current.',
                                                                              'citation_indexes' => [] }] } },
                 { content:
                   :steps_with_media,
                   content_type: 'text',
                   additional_attributes: { 'captain_v2_response_parts' => [{ 'text' => :steps,
                                                                              'citation_indexes' => [1] }] } }]
    },
    product_cards: {
      state: :products,
      response: { 'agent_name' => 'Acme', 'response_parts' => [{ 'text' => 'The Trail Boot is waterproof.', 'citation_indexes' => [] }],
                  'product_handles' => %w[trail-boot], 'suggested_replies' => ['Sizes'] },
      expected: [{ content: 'The Trail Boot is waterproof.',
                   content_type: 'text',
                   additional_attributes: { :agent_name => 'Acme',
                                            'captain_v2_response_parts' => [{ 'text' => 'The Trail Boot is waterproof.',
                                                                              'citation_indexes' => [] }] } },
                 { content: 'Trail Boot',
                   content_type: 'cards',
                   content_attributes: { items: [{ 'title' => 'Trail Boot',
                                                   'description' => '129.00 EUR',
                                                   'media_url' => 'https://cdn.shopify.com/boot.jpg',
                                                   'actions' => [{ 'type' => 'link',
                                                                   'text' => 'View product',
                                                                   'uri' => 'https://acme-outdoor.test/products/trail-boot' }] }] },
                   additional_attributes: { agent_name: 'Acme', product_handles: ['trail-boot'] } },
                 { content: nil,
                   additional_attributes: { agent_name: 'Acme' },
                   content_type: 'input_select',
                   content_attributes: { items: [{ 'title' => 'Sizes', 'value' => 'Sizes' }], submit_value: true } }]
    },
    product_cards_with_question: {
      state: :products,
      response: { 'agent_name' => 'Acme',
                  'response_parts' => [{ 'text' => 'We have one waterproof boot. Which size do you wear?', 'citation_indexes' => [] }],
                  'product_handles' => %w[trail-boot],
                  'suggested_replies' => [{ 'label' => 'EU 42', 'message' => 'I wear EU 42.' }] },
      expected: [{ content: 'We have one waterproof boot.',
                   content_type: 'text',
                   additional_attributes: { :agent_name => 'Acme',
                                            'captain_v2_response_parts' => [{ 'text' => 'We have one waterproof boot.',
                                                                              'citation_indexes' => [] }] } },
                 { content: 'Trail Boot',
                   content_type: 'cards',
                   content_attributes: { items: [{ 'title' => 'Trail Boot',
                                                   'description' => '129.00 EUR',
                                                   'media_url' => 'https://cdn.shopify.com/boot.jpg',
                                                   'actions' => [{ 'type' => 'link',
                                                                   'text' => 'View product',
                                                                   'uri' => 'https://acme-outdoor.test/products/trail-boot' }] }] },
                   additional_attributes: { agent_name: 'Acme', product_handles: ['trail-boot'] } },
                 { content: 'Which size do you wear?',
                   additional_attributes: { agent_name: 'Acme' },
                   content_type: 'input_select',
                   content_attributes: { items: [{ 'title' => 'EU 42', 'value' => 'I wear EU 42.' }], submit_value: true } }]
    },
    order_card: {
      state: :order,
      response: { 'response_parts' => [{ 'text' => 'Your order is paid. Anything else?', 'citation_indexes' => [] }],
                  'suggested_replies' => ['Track order'] },
      expected: [{ content: 'Your order is paid.',
                   content_type: 'text',
                   additional_attributes: { 'captain_v2_response_parts' => [{ 'text' => 'Your order is paid.', 'citation_indexes' => [] }] } },
                 { content: '1001',
                   content_type: 'cards',
                   content_attributes: { items: [{ 'title' => '1001', 'description' => 'Paid · Not shipped yet', 'actions' => [] }] } },
                 { content: 'Anything else?',
                   additional_attributes: {},
                   content_type: 'input_select',
                   content_attributes: { items: [{ 'title' => 'Track order', 'value' => 'Track order' }], submit_value: true } }]
    },
    followup_form: {
      state: :followup_form,
      response: { 'response_parts' => [{ 'text' => 'A specialist can walk you through pricing. What is your email?',
                                         'citation_indexes' => [] }],
                  'suggested_replies' => ['Later'] },
      expected: [{ content: 'A specialist can walk you through pricing.',
                   content_type: 'text',
                   additional_attributes: { 'captain_v2_response_parts' => [{ 'text' => 'A specialist can walk you through pricing.',
                                                                              'citation_indexes' => [] }] } },
                 { content: 'Where should our team send your follow-up?',
                   content_type: 'form',
                   content_attributes: { 'type' => 'contact_capture',
                                         'items' => [{ 'name' => 'name',
                                                       'label' => 'Name',
                                                       'type' => 'text',
                                                       'placeholder' => 'Please enter your name',
                                                       'required' => true }],
                                         'button_label' => 'Request email follow-up',
                                         'purpose' => 'business_followup' },
                   additional_attributes: { agent_name: :assistant_agent_name } }]
    },
    followup_form_question_only: {
      state: :followup_form,
      response: { 'response_parts' => [{ 'text' => 'Could you share your email?', 'citation_indexes' => [] }] },
      expected: [{ content: 'Where should our team send your follow-up?',
                   content_type: 'form',
                   content_attributes: { 'type' => 'contact_capture',
                                         'items' => [{ 'name' => 'name',
                                                       'label' => 'Name',
                                                       'type' => 'text',
                                                       'placeholder' => 'Please enter your name',
                                                       'required' => true }],
                                         'button_label' => 'Request email follow-up',
                                         'purpose' => 'business_followup' },
                   additional_attributes: { agent_name: :assistant_agent_name } }]
    },
    action_confirmation: {
      state: :action_confirmation,
      response: { 'response' => 'Sure.', 'suggested_replies' => ['Track order'] },
      expected: [{ content: 'Sure.',
                   content_type: 'text',
                   additional_attributes: { 'captain_v2_response_parts' => [{ 'text' => 'Sure.', 'citation_indexes' => [] }] } },
                 { content: 'Cancel order #1001?',
                   content_type: 'input_select',
                   content_attributes: { :items => [{ title: 'Confirm', value: 'confirm' }, { title: 'Cancel', value: 'cancel' }],
                                         'captain_action_confirmation' => 'nonce-1' } }]
    },
    handoff_suppressed: {
      suppress: true, stub_citations: true, state: :knowledge_media,
      response: { 'handoff_requested' => true, 'response_parts' => [{ 'text' => :steps, 'citation_indexes' => [1] }],
                  'suggested_replies' => ['Sync now'] },
      expected: [{ content: :steps,
                   content_type: 'text',
                   additional_attributes: { 'captain_v2_response_parts' => [{ 'text' => :steps,
                                                                              'citation_indexes' => [1] }] } }]
    },
    empty_catalog: {
      state: :empty_catalog,
      response: { 'response' => '', 'response_parts' => [] },
      expected: [{ content: "I couldn't find a matching product in our current catalog.",
                   content_type: 'text',
                   additional_attributes: { 'captain_v2_response_parts' =>
                                              [{ 'text' => "I couldn't find a matching product in our current catalog.",
                                                 'citation_indexes' => [] }] } }]
    },
    empty_with_attachments: {
      attachments: true,
      response: { 'response' => '', 'response_parts' => [] },
      expected: [{ content: 'Please send a short message explaining what to check.',
                   content_type: 'text',
                   additional_attributes: { 'captain_v2_response_parts' => [{ 'text' => 'Please send a short message explaining what to check.',
                                                                              'citation_indexes' => [] }] } }]
    },
    empty_unusable: {
      response: { 'response' => 'Sync runs every five minutes.', 'response_parts' => [{ 'text' => '[1]', 'citation_indexes' => [] }] },
      expected: [{ content: 'Sorry, I did not catch that. Could you rephrase?',
                   content_type: 'text',
                   additional_attributes: { 'captain_v2_response_parts' => [{ 'text' => 'Sorry, I did not catch that. Could you rephrase?',
                                                                              'citation_indexes' => [] }] } }]
    },
    empty_handoff: {
      response: { 'response' => '', 'response_parts' => [] },
      expected: [{ content: "I couldn't complete that request. A colleague will continue with you in this chat.",
                   content_type: 'text',
                   additional_attributes: {
                     'captain_v2_response_parts' => [
                       { 'text' => "I couldn't complete that request. A colleague will continue with you in this chat.", 'citation_indexes' => [] }
                     ]
                   } }]
    }
  }

  def tool_state(kind)
    case kind
    when :knowledge_media
      { knowledge_screenshots: ['https://docs.lumen-notes.test/sync.png'], knowledge_media: { 1 => [video, screenshot] } }
    when :products
      { Captain::Assistant::PRODUCT_HANDLES_STATE_KEY => %w[trail-boot], Captain::Assistant::PRODUCT_CACHE_STATE_KEY => product_cache }
    when :order
      { Captain::Assistant::ORDER_STATE_KEY => { 'order_number' => '#1001', 'financial_status' => 'PAID', 'items' => [] } }
    when :followup_form then { lead_followup_form_requested: true }
    when :action_confirmation
      { Captain::Tools::ActionConfirmation::STATE_KEY => { 'nonce' => 'nonce-1', 'content' => 'Cancel order #1001?' } }
    when :empty_catalog then { Captain::Assistant::PRODUCT_SEARCH_STATS_STATE_KEY => { searches: 2, results: 0 } }
    else {}
    end
  end

  def resolve(value)
    value.deep_transform_values { |item| placeholders.fetch(item, item) }
  end

  cases.each do |name, input|
    it "composes #{name}" do
      assistant.update!(config: assistant.config.merge('feature_citation' => true)) if input[:citations]
      if input[:citations] || input[:stub_citations]
        allow(assistant).to receive_messages(trusted_citation_urls: citation_urls, citation_titles: citation_titles)
      end
      inbox = create(:inbox, account: account, channel: channels.fetch(input.fetch(:channel, :widget)).call)
      conversation = create(:conversation, account: account, inbox: inbox)
      run_result = instance_double(Agents::RunResult, context: { state: tool_state(input[:state]) })
      customer_message = instance_double(Message, attachments: [instance_double(Attachment)]) if input[:attachments]
      composer = Captain::Conversation::ReplyComposer.new(assistant: assistant, conversation: conversation, response: resolve(input[:response]),
                                                          run_result: run_result, customer_message: customer_message)

      messages = composer.messages(suppress_suggestions: input.fetch(:suppress, false))

      expect(messages).to eq(input[:expected].map { |payload| resolve(payload) })
    end
  end
end
