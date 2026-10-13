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

    it 'normalizes and validates conversation starters with actions' do
      channel_widget.conversation_starters = [
        { 'title' => 'Chat on WhatsApp', 'enabled' => 'true', 'action_type' => 'url', 'target' => ' https://wa.me/12345 ' },
        { 'title' => 'Return policy', 'enabled' => true, 'action_type' => 'canned', 'target' => '30 days return' },
        { 'title' => 'Ask AI', 'enabled' => false }
      ]
      expect(channel_widget).to be_valid
      expect(channel_widget.conversation_starters.first['action_type']).to eq 'url'
      expect(channel_widget.conversation_starters.first['target']).to eq 'https://wa.me/12345'
      expect(channel_widget.conversation_starters.last['action_type']).to eq 'message'
    end

    it 'rejects conversation starters with missing targets for url and canned actions' do
      channel_widget.conversation_starters = [
        { 'title' => 'Chat on WhatsApp', 'enabled' => true, 'action_type' => 'url', 'target' => '' }
      ]
      expect(channel_widget).not_to be_valid
    end
  end

  describe 'demo slug' do
    let(:account) { create(:account, name: 'Acme') }
    let!(:channel_widget) { create(:channel_widget, account: account) }

    it 'is derived from the account name when demo mode is switched on' do
      channel_widget.update!(demo_mode_enabled: true)

      expect(channel_widget.demo_slug).to eq 'acme'
    end

    it 'falls back to the inbox name for a second demo on the same account' do
      create(:channel_widget, account: account, demo_slug: 'acme')
      channel_widget.inbox.update!(name: 'B2B Portal')

      channel_widget.update!(demo_mode_enabled: true)

      expect(channel_widget.demo_slug).to eq 'acme-b2b-portal'
    end

    it 'adds a random suffix when both are taken' do
      create(:channel_widget, account: account, demo_slug: 'acme')
      create(:channel_widget, account: account, demo_slug: 'acme-b2b-portal')
      channel_widget.inbox.update!(name: 'B2B Portal')

      channel_widget.update!(demo_mode_enabled: true)

      expect(channel_widget.demo_slug).to match(/\Aacme-[a-z0-9]{4}\z/)
    end

    it 'keeps a slug that was chosen by hand' do
      channel_widget.update!(demo_mode_enabled: true, demo_slug: 'ask-acme')

      expect(channel_widget.demo_slug).to eq 'ask-acme'
    end

    it 'rejects a slug that is not url safe' do
      channel_widget.demo_slug = 'Acme Storefront!'

      expect(channel_widget).not_to be_valid
    end
  end
end
