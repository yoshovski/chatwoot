require 'rails_helper'

RSpec.describe Captain::Knowledge::PageCleaner do
  def clean(markdown, boilerplate: []) = described_class.new(markdown, boilerplate: boilerplate, url: 'https://example.com/refunds').perform

  it 'keeps prose, drops logos and copyright lines, and lists button and menu targets once' do
    markdown = <<~MD
      ![cleeng logo](https://cdn.example.com/logo.svg)

      ## **Refunds**

      Refunds are issued within 14 days of a request, to the original payment method.

      [Get started free](https://example.com/register?utm_source=site&plan=pro)

      See a demo

      - [Pricing](/pricing)
      - [Blog](/blog)
      - [Contact](/contact)

      Copyright © 2026 Example | All Rights Reserved
    MD

    expect(clean(markdown)).to eq(
      "## Refunds\n\nRefunds are issued within 14 days of a request, to the original payment method.\n\n## Links\n\n" \
      "- Get started free: https://example.com/register?plan=pro\n- Pricing: https://example.com/pricing\n" \
      "- Blog: https://example.com/blog\n- Contact: https://example.com/contact"
    )
  end

  it 'keeps a video line next to the steps it shows' do
    markdown = "You may refer to this video below:\n\n[Video](https://fast.wistia.net/embed/iframe/qnyqws7m7j)\n\n" \
               'For easier steps, use these instructions for Google Chrome.'

    expect(described_class.new(markdown, url: 'https://support.example.com/a').perform).to eq(
      "You may refer to this video below:\n\n[Video](https://fast.wistia.net/embed/iframe/qnyqws7m7j)\n\n" \
      'For easier steps, use these instructions for Google Chrome.'
    )
  end

  it 'keeps a few prose links as absolute URLs and descriptive image text' do
    markdown = 'Read the [shipping policy](/shipping#costs) first. ![Chart of refunds by month](/chart.png)'

    expect(clean(markdown)).to eq('Read the [shipping policy](https://example.com/shipping) first. Chart of refunds by month')
  end

  it 'keeps only the text of links in link-dense prose and skips in-page anchors' do
    markdown = 'Plans include [billing](/a), [tax](/b), [fraud](/c) and [analytics](/d) for every [store](#top).'

    expect(clean(markdown)).to eq('Plans include billing, tax, fraud and analytics for every store.')
  end

  it 'keeps a one-off card title followed by its description but drops repeated buttons' do
    markdown = "Partial refunds\n\nRefund part of a payment when a customer reports a problem with their order.\n\n" \
               "See a demo\n\nOffer management lets you build pricing tiers, promotions and segments for subscribers.\n\nSee a demo"

    expect(clean(markdown)).to eq(
      "Partial refunds\n\nRefund part of a payment when a customer reports a problem with their order.\n\n" \
      'Offer management lets you build pricing tiers, promotions and segments for subscribers.'
    )
  end

  it 'drops headings left without content and card-link wrappers, listing their targets' do
    markdown = "## Related articles\n\n- [Billing](/billing)\n- [Accounts](/accounts)\n\n" \
               "[\n\n## Pricing\n\nPlans start at 10 euros per month for every subscriber.\n\n](/pricing)"

    expect(clean(markdown)).to eq("## Pricing\n\nPlans start at 10 euros per month for every subscriber.\n\n## Links\n\n" \
                                  "- Billing: https://example.com/billing\n- Accounts: https://example.com/accounts")
  end

  it 'splits headings from trailing edit links and does not list repeated action links' do
    parts = (1..3).map do |index|
      "## Part #{index}\n[[edit](/w/index.php?action=edit&section=#{index})]\n\nVendors plan revenue over #{index} years."
    end

    expect(clean(parts.join("\n\n"))).to eq((1..3).map { |index| "## Part #{index}\n\nVendors plan revenue over #{index} years." }.join("\n\n"))
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
