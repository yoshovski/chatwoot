# Built-ins are computed, never editable CustomFilter rows. Saved references remain account scoped.
class Contacts::Segments
  BUILT_INS = %w[all online leads new waiting].freeze

  def initialize(account, user = nil)
    @account = account
    @user = user
  end

  def list
    built_ins = BUILT_INS.map do |id|
      { id: id, count: scope(id).count, built_in: true }
    end
    built_ins + @account.custom_filters.contact.where(user: @user).map do |segment|
      { id: "custom:#{segment.id}", name: segment.name, count: scope("custom:#{segment.id}").count, built_in: false }
    end
  end

  def scope(id)
    contacts = @account.contacts
    case id
    when 'all' then contacts
    when 'online' then contacts.where(id: online_ids)
    when 'leads' then contacts.resolved_contacts.where.not(contact_type: :customer)
    when 'new' then contacts.where(created_at: 7.days.ago..)
    when 'waiting' then contacts.where(id: @account.conversations.open.where.not(waiting_since: nil).select(:contact_id))
    else saved_scope(id)
    end
  end

  def valid_reference?(id)
    return true if BUILT_INS.include?(id)
    return false unless id.is_a?(String) && id.match?(/\Acustom:[1-9]\d*\z/)

    @account.custom_filters.contact.exists?(id: id.delete_prefix('custom:'))
  end

  def matches?(id, contact)
    return false unless contact.account_id == @account.id && valid_reference?(id)

    scope(id).exists?(id: contact.id)
  end

  private

  def online_ids
    @online_ids ||= OnlineStatusTracker.get_available_contact_ids(@account.id)
  end

  def saved_scope(id)
    raise ActiveRecord::RecordNotFound unless id.is_a?(String) && id.match?(/\Acustom:[1-9]\d*\z/)

    saved = @account.custom_filters.contact.find(id.delete_prefix('custom:'))
    Contacts::FilterService.new(@account, @user || saved.user, saved.query.with_indifferent_access).perform[:contacts]
  end
end
