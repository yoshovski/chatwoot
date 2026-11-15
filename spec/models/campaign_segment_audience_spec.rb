require 'rails_helper'

RSpec.describe Campaign do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, :with_email, account: account, created_at: 10.days.ago) }
  let(:campaign) { create(:campaign, account: account, inbox: inbox, audience: [{ 'type' => 'segment', 'id' => 'new' }]) }

  it 'checks membership for the current contact and excludes anonymous and foreign contacts' do
    expect(campaign.matches_contact_segment?(nil)).to be(false)
    expect(campaign.matches_contact_segment?(contact)).to be(false)
    contact.update!(created_at: Time.current)
    expect(campaign.matches_contact_segment?(contact)).to be(true)
    expect(campaign.matches_contact_segment?(create(:contact))).to be(false)
  end

  it 'rejects segment references from another account' do
    saved = create(:custom_filter, filter_type: :contact)
    campaign.audience = [{ 'type' => 'segment', 'id' => "custom:#{saved.id}" }]
    expect(campaign).not_to be_valid
  end

  it 'does not create a conversation when the opener is triggered outside its audience' do
    link = create(:contact_inbox, inbox: inbox, contact: contact)
    expect do
      Campaigns::CampaignConversationBuilder.new(contact_inbox_id: link.id, campaign_display_id: campaign.display_id).perform
    end.not_to change(Conversation, :count)
  end

  it 'rejects a malformed segment audience instead of applying it to everyone' do
    campaign.audience = { 'type' => 'segment', 'id' => 'new' }
    expect(campaign).not_to be_valid
    expect(campaign.matches_contact_segment?(contact)).to be(false)
  end
end
