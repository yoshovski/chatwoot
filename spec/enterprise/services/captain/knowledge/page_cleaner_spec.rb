require 'rails_helper'

RSpec.describe Captain::Knowledge::PageCleaner do
  def clean(markdown, boilerplate: []) = described_class.new(markdown, boilerplate: boilerplate).perform

  it 'keeps prose and drops buttons, menus, logos and copyright lines' do
    markdown = <<~MD
      ![cleeng logo](https://cdn.example.com/logo.svg)

      ## **Refunds**

      Refunds are issued within 14 days of a request, to the original payment method.

      [Get started free](https://example.com/register?utm=1)

      See a demo

      - [Pricing](/pricing)
      - [Blog](/blog)
      - [Contact](/contact)

      Copyright © 2026 Example | All Rights Reserved
    MD

    expect(clean(markdown)).to eq("## Refunds\n\nRefunds are issued within 14 days of a request, to the original payment method.")
  end

  it 'unwraps links in prose and keeps descriptive image text' do
    markdown = 'Read the [refund policy](https://example.com/refunds) first. ![Chart of refunds by month](/chart.png)'

    expect(clean(markdown)).to eq('Read the refund policy first. Chart of refunds by month')
  end

  it 'keeps a one-off card title followed by its description but drops repeated buttons' do
    markdown = "Partial refunds\n\nRefund part of a payment when a customer reports a problem with their order.\n\n" \
               "See a demo\n\nOffer management lets you build pricing tiers, promotions and segments for subscribers.\n\nSee a demo"

    expect(clean(markdown)).to eq(
      "Partial refunds\n\nRefund part of a payment when a customer reports a problem with their order.\n\n" \
      'Offer management lets you build pricing tiers, promotions and segments for subscribers.'
    )
  end

  it 'drops headings left without content and card-link wrappers' do
    markdown = "## Related articles\n\n- [Billing](/billing)\n- [Accounts](/accounts)\n\n" \
               "[\n\n## Pricing\n\nPlans start at 10 euros per month for every subscriber.\n\n](/pricing)"

    expect(clean(markdown)).to eq("## Pricing\n\nPlans start at 10 euros per month for every subscriber.")
  end

  it 'splits headings from trailing edit links' do
    expect(clean("## Effects\n[[edit](/w/index.php?action=edit)]\n\nSubscriptions change how vendors plan revenue over many years."))
      .to eq("## Effects\n\nSubscriptions change how vendors plan revenue over many years.")
  end

  it 'removes blocks learned as site-wide boilerplate and repeated copies' do
    banner = 'Free shipping on all orders over 50 euros this month for every customer.'
    markdown = "#{banner}\n\nWarranty covers two years from the date of delivery for every device.\n\n" \
               'Warranty covers two years from the date of delivery for every device.'

    expect(clean(markdown, boilerplate: [described_class.block_hash(banner)]))
      .to eq('Warranty covers two years from the date of delivery for every device.')
  end

  it 'keeps tables and code blocks with blank lines intact' do
    markdown = "| Plan | Price |\n| --- | --- |\n| Pro | 10 |\n\n```ruby\nputs 1\n\nputs 2\n```"

    expect(clean(markdown)).to eq(markdown)
  end
end
