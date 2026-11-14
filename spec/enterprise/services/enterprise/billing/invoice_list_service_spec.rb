require 'rails_helper'

describe Enterprise::Billing::InvoiceListService do
  let(:account) { create(:account) }
  let(:invoice_list) do
    Stripe::ListObject.construct_from(
      object: 'list',
      data: [
        { id: 'in_2', object: 'invoice', status: 'paid', created: 1.day.ago.to_i, total: 800, currency: 'eur',
          description: '50 extra AI conversations', invoice_pdf: 'https://stripe.test/in_2.pdf', hosted_invoice_url: 'https://stripe.test/in_2',
          lines: { data: [] } },
        { id: 'in_1', object: 'invoice', status: 'open', created: 3.days.ago.to_i, total: 3900, currency: 'eur', description: nil,
          invoice_pdf: 'https://stripe.test/in_1.pdf', hosted_invoice_url: 'https://stripe.test/in_1',
          lines: { data: [{ description: '1 × Growth (at €39.00 / month)' }] } },
        { id: 'in_0', object: 'invoice', status: 'draft', created: 4.days.ago.to_i, total: 3900, currency: 'eur', description: nil,
          invoice_pdf: nil, hosted_invoice_url: nil, lines: { data: [] } }
      ]
    )
  end

  it 'lists the latest invoices with a description, without drafts' do
    account.update!(subscription_settings: { enabled: true })
    account.account_subscription.update!(stripe_customer_id: 'cus_1')
    allow(Stripe::Invoice).to receive(:list).with(customer: 'cus_1', limit: 12).and_return(invoice_list)

    invoices = described_class.new(account: account).perform

    expect(invoices.pluck(:id)).to eq(%w[in_2 in_1])
    expect(invoices.first).to include(description: '50 extra AI conversations', total: 800, status: 'paid',
                                      pdf_url: 'https://stripe.test/in_2.pdf')
    expect(invoices.second).to include(description: '1 × Growth (at €39.00 / month)', pay_url: 'https://stripe.test/in_1')
  end

  it 'returns nothing for an account without a Stripe customer' do
    allow(Stripe::Invoice).to receive(:list)

    expect(described_class.new(account: account).perform).to eq([])
    expect(Stripe::Invoice).not_to have_received(:list)
  end
end
