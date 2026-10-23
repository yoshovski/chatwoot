require 'rails_helper'

RSpec.describe Captain::Conversation::ReplySanitizer do
  let(:assistant) { create(:captain_assistant, config: { 'link_allowlist' => ['https://shop.example.com'] }) }
  let(:sanitizer) { described_class.new(assistant: assistant) }

  describe '#sanitize_prose' do
    it 'keeps allowed links and drops others, whether markdown, autolinked or written out' do
      content = 'See [our policy](https://shop.example.com/policies/refund), <https://evil.example.net/a> ' \
                'or https://shop.example.com/pages/contact. Not https://evil.example.net/phish, though.'

      expect(sanitizer.sanitize_prose(content)).to eq(
        'See [our policy](https://shop.example.com/policies/refund), or https://shop.example.com/pages/contact. Not, though.'
      )
    end

    it 'keeps the text of a disallowed markdown link' do
      expect(sanitizer.sanitize_prose('Read [the guide](https://evil.example.net/guide).')).to eq('Read the guide.')
    end

    it 'keeps an endpoint written as code when the sources show it the same way' do
      knowledge = '* `POST https://inapp.api.sandbox.example.com/storekit2/purchases` in sandbox'
      evidence = knowledge.scan(described_class::BARE_URL_REGEX)
      reply = 'Send `POST https://inapp.api.sandbox.example.com/storekit2/purchases` in sandbox.'

      expect(evidence).to eq(['https://inapp.api.sandbox.example.com/storekit2/purchases'])
      expect(described_class.new(assistant: create(:captain_assistant, config: {}), evidence_urls: evidence).sanitize_prose(reply))
        .to eq(reply)
    end

    it 'keeps only the text of a link too long to be a page, such as a sign-in redirect' do
      login = "https://identity.example.com/Account/Login?ReturnUrl=#{'a' * 400}"

      expect(described_class.new(assistant: create(:captain_assistant, config: {})).sanitize_prose("Log in to the [portal](#{login})."))
        .to eq('Log in to the portal.')
    end

    context 'when link_allowlist is not configured (default wildcard)' do
      let(:assistant) { create(:captain_assistant, config: {}) }

      it 'allows all valid markdown links by default' do
        expect(sanitizer.sanitize_prose('Contact us on [WhatsApp](https://api.whatsapp.com/send).')).to eq(
          'Contact us on [WhatsApp](https://api.whatsapp.com/send).'
        )
      end
    end

    it 'replaces em dash and en dash with comma while keeping hyphens in words and number ranges' do
      content = 'We have 10-20 sizes for this T-shirt — check it out – they are great.'

      expect(sanitizer.sanitize_prose(content)).to eq(
        'We have 10-20 sizes for this T-shirt, check it out, they are great.'
      )
    end

    it 'replaces em and en dashes without spaces between words' do
      content = 'Great choice—we recommend this–check it out.'

      expect(sanitizer.sanitize_prose(content)).to eq(
        'Great choice, we recommend this, check it out.'
      )
    end

    it 'strips stray unlinked citation numbers while preserving linked citations' do
      content = 'Most systems guide you through activation and firmware in the manufacturer app. [1]'
      expect(sanitizer.sanitize_prose(content)).to eq(
        'Most systems guide you through activation and firmware in the manufacturer app.'
      )

      linked = 'See [1](https://shop.example.com/guide) and [[2](https://shop.example.com/faq)].'
      expect(sanitizer.sanitize_prose(linked)).to eq(
        'See [1](https://shop.example.com/guide) and [[2](https://shop.example.com/faq)].'
      )
    end
  end
end
