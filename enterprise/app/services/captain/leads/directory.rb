class Captain::Leads::Directory
  STATUSES = %w[new contacted won lost].freeze
  STATUS_SQL = "COALESCE(conversations.additional_attributes #>> '{lead_management,status}', 'new')".freeze
  CAPTURED_SQL = "COALESCE((conversations.additional_attributes ->> 'business_lead_captured_at')::timestamptz, conversations.created_at)".freeze
  PAGE_SIZE = 25

  def initialize(account, user)
    @account = account
    @user = user
  end

  def scope
    leads = @account.conversations.where('conversations.additional_attributes @> ?', { business_lead_captured: true }.to_json)
    Conversations::PermissionFilterService.new(leads, @user, @account).perform
  end

  def filtered(status)
    status.present? ? scope.where("#{STATUS_SQL} = ?", status) : scope
  end

  def ordered(status)
    filtered(status).reorder(Arel.sql("#{CAPTURED_SQL} DESC, conversations.id DESC")).includes(:contact)
  end

  def counts
    STATUSES.index_with(0).merge(scope.group(Arel.sql(STATUS_SQL)).count)
  end

  def rows(conversations)
    owner_ids = conversations.filter_map { |conversation| conversation.additional_attributes.dig('lead_management', 'owner_id') }
    owners = @account.users.where(id: owner_ids).index_by(&:id)
    hook = @account.hooks.find_by(app_id: 'hubspot', status: :enabled)
    conversations.map { |conversation| row(conversation, owners, hook) }
  end

  private

  def row(conversation, owners, hook)
    summary = Captain::Conversation::Summary.read(conversation).to_h
    lead = summary.fetch('lead', {})
    management = conversation.additional_attributes['lead_management'].to_h
    contact = conversation.contact
    { id: conversation.display_id, conversation_id: conversation.display_id,
      name: contact.name, email: contact.email, company: lead.dig('fields', 'company'),
      wants: lead['summary'] || summary['wants'], type: lead['type'], fields: lead['fields'] || {},
      status: management.fetch('status', 'new'), owner: owners[management['owner_id']]&.slice(:id, :name),
      hubspot: hubspot_state(contact, hook),
      captured_at: conversation.additional_attributes['business_lead_captured_at'] || conversation.created_at.iso8601 }
  end

  def hubspot_state(contact, hook)
    return 'off' unless hook&.settings&.fetch('sync_contacts', false)
    return 'synced' if contact.additional_attributes['hubspot_sync_status'] == 'synced'

    'not_synced'
  end
end
