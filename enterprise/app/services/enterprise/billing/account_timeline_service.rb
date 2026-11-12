# The billing history of one account on its Super Admin page (T10), newest first: Stripe webhook events, ledger rows
# for extra AI conversations, plan and status changes, and the actions taken in Super Admin. Reads only the database.
# Billing emails are not recorded yet (T08).
class Enterprise::Billing::AccountTimelineService
  LIMIT = 100
  Entry = Struct.new(:at, :kind, :title, :detail, :stripe_event_id, keyword_init: true)

  def initialize(account:)
    @account = account
    @subscription = account.account_subscription
  end

  def perform
    (stripe_entries + ledger_entries + audit_entries).select(&:at).sort_by(&:at).reverse.first(LIMIT)
  end

  def stripe_events
    customer_id = @subscription&.stripe_customer_id
    return StripeEvent.none if customer_id.blank?

    StripeEvent.for_customer(customer_id).order(created_at: :desc).limit(LIMIT)
  end

  private

  def stripe_entries
    stripe_events.map do |event|
      Entry.new(at: event.stripe_created_at || event.created_at, kind: 'stripe', title: event.event_type,
                detail: stripe_detail(event), stripe_event_id: event.id)
    end
  end

  def stripe_detail(event)
    object = event.payload.dig('data', 'object') || {}
    parts = ["status #{event.status}"]
    parts << "attempts #{event.attempts}" if event.attempts.to_i > 1
    parts << event.error.truncate(160) if event.error.present?
    cancellation = (object['cancellation_details'] || {}).compact_blank
    parts << "cancel: #{cancellation.values.join(' · ')}" if cancellation.present? && cancelling?(event, object)
    parts.join(' · ')
  end

  def cancelling?(event, object)
    event.event_type == 'customer.subscription.deleted' || object['cancel_at_period_end'] || object['cancel_at'].present?
  end

  # Usage rows (one per AI conversation over the allowance) are left out; the overview shows the totals.
  def ledger_entries
    @account.extra_ai_conversation_entries.where.not(reason: 'usage').includes(:user).order(created_at: :desc).limit(LIMIT).map do |entry|
      detail = [entry.note, entry.user&.email && "by #{entry.user.email}", entry.stripe_reference].compact.join(' · ')
      Entry.new(at: entry.created_at, kind: 'ledger', title: "#{entry.reason} #{format('%+d', entry.amount)}", detail: detail)
    end
  end

  def audit_entries
    return [] unless @subscription

    Audited.audit_class.where(auditable: @subscription).order(created_at: :desc).limit(LIMIT).map do |audit|
      Entry.new(at: audit.created_at, kind: audit.comment.present? ? 'action' : 'change',
                title: audit.comment.presence || "subscription #{audit.action}",
                detail: [change_summary(audit.audited_changes), audit.username && "by #{audit.username}"].compact_blank.join(' · '))
    end
  end

  def change_summary(changes)
    (changes || {}).map do |field, value|
      values = Array.wrap(value)
      values = values.map { |id| plan_name(id) } if field == 'billing_plan_id'
      "#{field.delete_suffix('_id').humanize.downcase} #{values.map { |item| item.nil? ? '—' : item }.join(' → ')}"
    end.join(', ')
  end

  def plan_name(id)
    id && (BillingPlan.find_by(id: id)&.name || id)
  end
end
