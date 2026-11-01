require 'rails_helper'

RSpec.describe Captain::Evals::Checks do
  let(:messages) { ['To clear the cache in Chrome, open the three-dot menu and choose Delete browsing data.'] }
  let(:observation) do
    {
      messages: messages.map { |content| { 'content' => content, 'content_type' => 'text' } },
      route: { 'intent' => 'faq_kb', 'reason' => 'classified' }, handoff: false,
      fixture_urls: ['https://help.acme-streaming.test/clear-cache'], link_allowlist: ['*']
    }
  end

  def check(spec) = described_class.run(spec, observation)

  it 'rejects an unknown check' do
    expect { check('sounds_nice') }.to raise_error(ArgumentError, /Unknown check/)
  end

  describe 'welcome_once' do
    it 'passes a welcome followed by the answer' do
      messages.unshift('Hello and welcome to Acme! I can help with that.')
      expect(check('welcome_once')[:pass]).to be(true)
    end

    it 'fails the CWAI-141 reply that repeats its welcome' do
      messages.replace(["Hello and welcome! I can certainly help you with that.\n\nHello and welcome! I can certainly help you with that. " \
                        "1. Click the three-dot menu.\n2. Choose Delete browsing data."])
      expect(check('welcome_once')).to include(pass: false, detail: /repeated/)
    end

    it 'passes a welcome of two short greeting sentences' do
      messages.unshift('Hi there! Welcome to Acme.')
      expect(check('welcome_once')[:pass]).to be(true)
    end

    it 'fails a second bubble that greets again' do
      messages.replace(['Hi there! Welcome to Acme.', 'Hello! To clear the cache, open the menu.'])
      expect(check('welcome_once')).to include(pass: false, detail: /2 welcomes/)
    end

    it 'fails a greeting after the answer started' do
      messages.replace(['Hi! To clear the cache, open the menu. Hello and welcome to Acme!'])
      expect(check('welcome_once')).to include(pass: false, detail: /2 welcomes/)
    end
  end

  describe 'starts_with_greeting' do
    it 'reads the first sentence of the first bubble' do
      messages.unshift('Hi there! Happy to help.')
      expect(check({ 'starts_with_greeting' => true })[:pass]).to be(true)
      expect(check({ 'starts_with_greeting' => false })[:pass]).to be(false)
    end

    it 'does not count an answer as a greeting' do
      expect(check({ 'starts_with_greeting' => false })[:pass]).to be(true)
    end
  end

  describe 'no_repeated_sentences' do
    it 'fails a sentence repeated across bubbles' do
      messages << 'To clear the cache in Chrome, open the three-dot menu and choose Delete browsing data.'
      expect(check('no_repeated_sentences')[:pass]).to be(false)
    end

    it 'passes short repeated phrases' do
      messages.replace(['Yes, please.', 'Yes, please.'])
      expect(check('no_repeated_sentences')[:pass]).to be(true)
    end
  end

  describe 'no_empty_bubbles' do
    it 'accepts suggestion buttons and forms without text' do
      observation[:messages] << { 'content' => nil, 'content_type' => 'input_select', 'content_attributes' => { 'items' => [{ 'title' => 'Yes' }] } }
      observation[:messages] << { 'content' => '', 'content_type' => 'form' }
      expect(check('no_empty_bubbles')[:pass]).to be(true)
    end

    it 'fails a blank text bubble' do
      observation[:messages] << { 'content' => ' ', 'content_type' => 'text' }
      expect(check('no_empty_bubbles')[:pass]).to be(false)
    end
  end

  it 'counts text bubbles for bubbles, ignoring forms' do
    observation[:messages] << { 'content' => 'Leave your email', 'content_type' => 'form' }
    expect(check({ 'bubbles' => { 'min' => 1, 'max' => 1 } })[:pass]).to be(true)
    expect(check({ 'bubbles' => { 'min' => 2 } })[:pass]).to be(false)
  end

  describe 'question_bubble' do
    it 'passes a single question in its own last bubble' do
      messages << 'Which browser do you use?'
      expect(check({ 'question_bubble' => true })[:pass]).to be(true)
    end

    it 'fails a question the answer bubble also asks' do
      messages.replace(['You can clear it in the browser menu. Which browser do you use?', 'Which browser do you use?'])
      expect(check({ 'question_bubble' => true })[:pass]).to be(false)
    end

    it 'fails a question inside the answer bubble' do
      messages.replace(['You can clear it in the browser menu. Which browser do you use?'])
      expect(check({ 'question_bubble' => true })[:pass]).to be(false)
      expect(check({ 'question_bubble' => false })[:pass]).to be(true)
    end
  end

  describe 'no_click_paths' do
    it 'fails admin click paths' do
      messages.replace(['Go to Settings > Billing > Plans to upgrade.'])
      expect(check('no_click_paths')[:pass]).to be(false)
    end

    it 'fails numbered admin steps' do
      messages.replace(["1. Open the admin dashboard.\n2. Choose Plans."])
      expect(check('no_click_paths')[:pass]).to be(false)
    end

    it 'passes an answer without them' do
      expect(check('no_click_paths')[:pass]).to be(true)
    end
  end

  describe 'links_from_knowledge' do
    it 'passes fixture links' do
      messages << '[Clear your cache](https://help.acme-streaming.test/clear-cache).'
      expect(check('links_from_knowledge')[:pass]).to be(true)
    end

    it 'fails an invented link even with the default allowlist' do
      messages << 'See https://acme-streaming.test/invented-page for details.'
      expect(check('links_from_knowledge')).to include(pass: false, detail: 'https://acme-streaming.test/invented-page')
    end

    it 'passes links on a configured allowlist' do
      observation[:link_allowlist] = ['https://status.acme-streaming.test/']
      messages << 'Status: https://status.acme-streaming.test/today'
      expect(check('links_from_knowledge')[:pass]).to be(true)
    end
  end

  it 'finds a video link line for contains_video' do
    messages << '[Video](https://fast.wistia.net/embed/iframe/acme0clear1)'
    expect(check({ 'contains_video' => true })[:pass]).to be(true)
  end

  it 'passes contains_video false without a video line' do
    expect(check({ 'contains_video' => false })[:pass]).to be(true)
  end

  it 'detects English' do
    expect(check({ 'language' => 'en' })[:pass]).to be(true)
  end

  it 'detects German' do
    messages.replace(['Die kostenlose Testphase dauert 14 Tage und Sie brauchen keine Kreditkarte für die Anmeldung.'])
    expect(check({ 'language' => 'de' })[:pass]).to be(true)
    expect(check({ 'language' => 'en' })[:pass]).to be(false)
  end

  it 'compares handoff and route with the run' do
    expect(check({ 'handoff' => false })[:pass]).to be(true)
    expect(check({ 'handoff' => true })[:pass]).to be(false)
    expect(check({ 'route' => 'faq_kb' })[:pass]).to be(true)
    expect(check({ 'route' => 'smalltalk' })).to include(pass: false, detail: 'route faq_kb (classified)')
  end

  it 'limits the text length with max_chars' do
    expect(check({ 'max_chars' => 200 })[:pass]).to be(true)
    expect(check({ 'max_chars' => 20 })[:pass]).to be(false)
  end

  it 'skips judge without a verdict and uses it when present' do
    expect(check({ 'judge' => 'Polite' })).to include(pass: true, detail: /skipped/)
    observation[:judgements] = { 'Polite' => 'FAIL' }
    expect(check({ 'judge' => 'Polite' })[:pass]).to be(false)
  end
end
