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
    let!(:channel_widget) { create(:channel_widget) }

    it 'is derived from the inbox name when demo mode is switched on' do
      channel_widget.inbox.update!(name: 'Scanixx Website')

      channel_widget.update!(demo_mode_enabled: true)

      expect(channel_widget.demo_slug).to eq 'scanixx-website'
    end

    it 'adds a suffix when the derived slug is taken' do
      create(:channel_widget, demo_slug: 'scanixx-website')
      channel_widget.inbox.update!(name: 'Scanixx Website')

      channel_widget.update!(demo_mode_enabled: true)

      expect(channel_widget.demo_slug).to match(/\Ascanixx-website-[a-z0-9]{4}\z/)
    end

    it 'keeps a slug that was chosen by hand' do
      channel_widget.update!(demo_mode_enabled: true, demo_slug: 'scanixx-b2b')

      expect(channel_widget.demo_slug).to eq 'scanixx-b2b'
    end

    it 'rejects a slug that is not url safe' do
      channel_widget.demo_slug = 'Scanixx Storefront!'

      expect(channel_widget).not_to be_valid
    end
  end
end
