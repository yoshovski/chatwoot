require 'rails_helper'

RSpec.describe Captain::Knowledge::ChunkPacker do
  let(:parent_separator) { Captain::Knowledge::SectionedText::SECTION_SEPARATOR }
  let(:sentence) { 'Refunds are issued to the original payment method within fourteen days of the request. ' }

  def pack(markdown, title: 'Help center') = described_class.new(markdown, title: title).to_s

  it 'packs small sections into one parent with context-led children' do
    markdown = "## Refunds\n\n#{sentence * 3}\n\n## Shipping\n\n#{sentence.sub('Refunds', 'Orders') * 3}"
    parents = pack(markdown).split(parent_separator)

    expect(parents.size).to eq(1)
    expect(parents.first.split(described_class::CHILD_SEPARATOR).map { |child| child.lines.first.chomp })
      .to eq(['Help center > Refunds', 'Help center > Shipping'])
  end

  it 'merges one-line sections into their neighbour with a shortened context' do
    markdown = "## Plans\n\n### Pro\n\nFor growing teams.\n\n### Enterprise\n\nFor large companies."

    expect(pack(markdown)).to eq("Help center > Plans > Pro\nFor growing teams.\nEnterprise\nFor large companies.")
  end

  it 'starts a new parent at a new top-level topic once the current one has enough text' do
    markdown = "## Refunds\n\n#{sentence * 12}\n\n## Shipping\n\n#{sentence * 3}"
    parents = pack(markdown).split(parent_separator)

    expect(parents.map { |parent| parent.lines.first.chomp }).to eq(['Help center > Refunds', 'Help center > Shipping'])
  end

  it 'keeps parents and children within their size targets' do
    markdown = (1..20).map { |index| "## Topic #{index}\n\n#{sentence * 4}" }.join("\n\n")
    parents = pack(markdown).split(parent_separator)
    children = parents.flat_map { |parent| parent.split(described_class::CHILD_SEPARATOR) }

    expect(parents.map(&:length).max).to be <= described_class::PARENT_TARGET + described_class::CHILD_TARGET
    expect(children.map(&:length).max).to be <= described_class::CHILD_TARGET + 150
  end

  it 'shortens deep breadcrumbs to the title and the two nearest headings and drops markdown' do
    markdown = "# **Guide**\n\n## Setup\n\n### [Payments](/payments)\n\n#### Cards\n\n#{sentence}"

    expect(pack(markdown, title: 'Docs').lines.first.chomp).to eq('Docs > Payments > Cards')
  end
end
