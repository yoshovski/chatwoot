require 'rails_helper'

RSpec.describe Captain::Documents::PageKnowledgeProcessor do
  let(:assistant) { create(:captain_assistant, config: { 'knowledge_processing_version' => 3 }) }
  let(:banner) { 'Free shipping on all orders over 50 euros this month for every customer.' }
  let(:source) do
    Captain::WebsiteSource.create!(assistant: assistant, url: 'https://www.example.com', status: 'ready',
                                   discovery_stats: { 'boilerplate' => { 'example.com' => [Captain::Knowledge::PageCleaner.block_hash(banner)] } })
  end
  let(:raw) { "#{banner}\n\nWarranty covers two years from the date of delivery for every device.\n\n[Get started](/signup)" }

  def document_for(url) = assistant.documents.new(external_link: url, metadata: { 'website_source_id' => source.id })

  it 'cleans version 3 pages and drops blocks repeated across the site' do
    expect(described_class.new(document_for('https://www.example.com/warranty')).preview(raw))
      .to eq("Warranty covers two years from the date of delivery for every device.\n\n## Links\n\n- Get started: https://www.example.com/signup")
  end

  it 'keeps site-wide blocks on the start page so they are indexed once' do
    expect(described_class.new(document_for('https://www.example.com')).preview(raw))
      .to eq("#{banner}\n\nWarranty covers two years from the date of delivery for every device.\n\n## Links\n\n" \
             '- Get started: https://www.example.com/signup')
  end

  it 'leaves version 1 agents untouched' do
    assistant.update!(config: assistant.config.merge('knowledge_processing_version' => 1))

    expect(described_class.new(document_for('https://www.example.com/warranty')).preview(raw)).to eq(raw)
  end
end
