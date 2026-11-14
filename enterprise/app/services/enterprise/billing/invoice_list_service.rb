# The account's latest Stripe invoices for the Billing page. Read live from Stripe when the page asks for them.
class Enterprise::Billing::InvoiceListService
  LIMIT = 12
  SHOWN_STATUSES = %w[open paid uncollectible].freeze

  def initialize(account:)
    @account = account
  end

  def perform
    customer = @account.account_subscription&.stripe_customer_id
    return [] if customer.blank?

    Stripe::Invoice.list(customer: customer, limit: LIMIT).data.select { |invoice| SHOWN_STATUSES.include?(invoice.status) }.map do |invoice|
      { id: invoice.id, created: Time.zone.at(invoice.created).iso8601, description: description(invoice), total: invoice.total,
        currency: invoice.currency, status: invoice.status, pdf_url: invoice.invoice_pdf, pay_url: invoice.hosted_invoice_url }
    end
  end

  private

  # A top-up invoice carries its own description; a subscription invoice names its plan in the first line.
  def description(invoice)
    invoice.description.presence || invoice.lines&.data&.first&.description
  end
end
