require 'rails_helper'

RSpec.describe Captain::Knowledge::SectionedText do
  def sectioned(markdown, title: 'Help center')
    described_class.new(markdown, title: title).to_s
  end

  it 'drops a heading-only block and prefixes the body below it with the breadcrumb' do
    markdown = "# Returns\n\n## RMA requirements\n\nItems must be unused.\nKeep the original box."

    expect(sectioned(markdown)).to eq("Help center > Returns > RMA requirements\nItems must be unused.\nKeep the original box.")
  end

  it 'gives every paragraph of a section the same breadcrumb' do
    markdown = "## Warranty\n\nFirst condition.\n\nSecond condition.\n\nThird condition."

    expect(sectioned(markdown).split("\n\n")).to eq(
      ["Help center > Warranty\nFirst condition.", "Help center > Warranty\nSecond condition.", "Help center > Warranty\nThird condition."]
    )
  end

  it 'reads a heading directly followed by its body in one block' do
    expect(sectioned("## Shipping\nOrders ship in two days.")).to eq("Help center > Shipping\nOrders ship in two days.")
  end

  it 'splits a block at a heading that follows body text' do
    expect(sectioned("Intro text.\n## Shipping\nOrders ship in two days.")).to eq(
      "Help center\nIntro text.\n\nHelp center > Shipping\nOrders ship in two days."
    )
  end

  it 'pops deeper headings when the level changes' do
    markdown = "# Returns\n\n## Window\n\n### Exceptions\n\nSale items.\n\n## Refunds\n\nRefunds take five days.\n\n# Warranty\n\nTwo years."

    expect(sectioned(markdown).split("\n\n").map { |block| block.lines.first.chomp }).to eq(
      ['Help center > Returns > Window > Exceptions', 'Help center > Returns > Refunds', 'Help center > Warranty']
    )
  end

  it 'uses only the title for text before the first heading' do
    expect(sectioned("Welcome text.\n\n# Returns\n\nBody.")).to eq("Help center\nWelcome text.\n\nHelp center > Returns\nBody.")
  end

  it 'removes consecutive duplicates such as an H1 equal to the title' do
    expect(sectioned("# Help Center\n\n## Returns\n\nBody.")).to eq("Help center > Returns\nBody.")
  end

  it 'leaves blocks unchanged when there is no title and no heading' do
    expect(sectioned("First paragraph.\n\nSecond paragraph.", title: nil)).to eq("First paragraph.\n\nSecond paragraph.")
  end

  it 'omits an empty title from the breadcrumb' do
    expect(sectioned("## Returns\n\nBody.", title: '')).to eq("Returns\nBody.")
  end

  it 'does not treat lines inside a code fence as headings' do
    markdown = "## Install\n\n```sh\n# not a heading\nrun it\n```"

    expect(sectioned(markdown)).to eq("Help center > Install\n```sh\n# not a heading\nrun it\n```")
  end

  it 'caps the breadcrumb by dropping the leftmost parts and keeping the deepest heading whole' do
    long = 'x' * 120
    result = sectioned("# #{long}\n\n## Deepest heading\n\nBody.", title: 'y' * 120)

    expect(result.lines.first.chomp).to eq("#{long} > Deepest heading")
  end

  it 'returns an empty string for empty content' do
    expect(sectioned(nil)).to eq('')
  end
end
