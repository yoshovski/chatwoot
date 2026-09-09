# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Channel::WebWidget do
  context 'when
  web widget channel' do
    let!(:channel_widget) { create(:channel_widget) }

    it 'pre chat options' do
      expect(channel_widget.pre_chat_form_options['pre_chat_message']).to eq 'Share your queries or comments here.'
      expect(channel_widget.pre_chat_form_options['pre_chat_fields'].length).to eq 3
    end
  end

  describe 'demo slug' do
    let(:account) { create(:account, name: 'Scanixx') }
    let!(:channel_widget) { create(:channel_widget, account: account) }

    it 'is derived from the account name when demo mode is switched on' do
      channel_widget.update!(demo_mode_enabled: true)

      expect(channel_widget.demo_slug).to eq 'scanixx'
    end

    it 'falls back to the inbox name for a second demo on the same account' do
      create(:channel_widget, account: account, demo_slug: 'scanixx')
      channel_widget.inbox.update!(name: 'B2B Portal')

      channel_widget.update!(demo_mode_enabled: true)

      expect(channel_widget.demo_slug).to eq 'scanixx-b2b-portal'
    end

    it 'adds a random suffix when both are taken' do
      create(:channel_widget, account: account, demo_slug: 'scanixx')
      create(:channel_widget, account: account, demo_slug: 'scanixx-b2b-portal')
      channel_widget.inbox.update!(name: 'B2B Portal')

      channel_widget.update!(demo_mode_enabled: true)

      expect(channel_widget.demo_slug).to match(/\Ascanixx-[a-z0-9]{4}\z/)
    end

    it 'keeps a slug that was chosen by hand' do
      channel_widget.update!(demo_mode_enabled: true, demo_slug: 'ask-scanixx')

      expect(channel_widget.demo_slug).to eq 'ask-scanixx'
    end

    it 'rejects a slug that is not url safe' do
      channel_widget.demo_slug = 'Scanixx Storefront!'

      expect(channel_widget).not_to be_valid
    end
  end
end
