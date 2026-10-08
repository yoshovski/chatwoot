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
  end
end
