class Captain::Conversation::ContactCaptureService # rubocop:disable Metrics/ClassLength
  FORM_TEXT = 'Please share your contact details so our team can follow up if you leave the chat.'.freeze
  ACKNOWLEDGEMENT_TEXT = 'Thank you—your contact details have been saved. A team member will continue with you here.'.freeze

  EMAIL_PATTERN = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/
  PLACEHOLDER_NAMES = %w[visitor guest anonymous unknown contact customer].freeze
  HAIKUNATOR_PATTERN = /\A[a-z]+-[a-z]+-\d+\z/i
  PLACEHOLDER_PATTERN = /\A(visitor|guest|anonymous|unknown|contact|customer)(\s*#?\d+)?\z/i
  GUARD_TTL = 7.days.to_i

  NAME_FORM_ITEM = {
    'name' => 'name', 'label' => 'Name', 'type' => 'text', 'placeholder' => 'Please enter your name', 'required' => true
  }.freeze
  EMAIL_FORM_ITEM = {
    'name' => 'email', 'label' => 'Email', 'type' => 'email', 'placeholder' => 'Please enter your email', 'required' => true
  }.freeze

  attr_reader :conversation, :assistant

  def initialize(conversation:, assistant: nil)
    @conversation = conversation
    @assistant = assistant || conversation&.inbox&.captain_assistant
  end

  # The form a customer sees when a handoff needs their details; the playground shows it without a conversation.
  def self.form_payload(missing_fields)
    items = []
    items << NAME_FORM_ITEM if missing_fields.include?('name')
    items << EMAIL_FORM_ITEM if missing_fields.include?('email')

    {
      content: FORM_TEXT,
      content_type: 'form',
      content_attributes: { 'type' => 'contact_capture', 'items' => items, 'button_label' => 'Submit' }
    }
  end

  def self.extract_email(text)
    return nil if text.blank?

    match = text.to_s.match(EMAIL_PATTERN)
    return nil unless match

    candidate = match[0].downcase.strip
    candidate.match?(URI::MailTo::EMAIL_REGEXP) ? candidate : nil
  end

  def self.missing_name?(contact)
    name = contact&.name.to_s.strip
    return true if name.length < 2 || PLACEHOLDER_NAMES.include?(name.downcase)

    name.match?(PLACEHOLDER_PATTERN) || name.match?(HAIKUNATOR_PATTERN)
  end

  def self.missing_email?(contact, triggering_message: nil)
    return false if triggering_message.present? && extract_email(triggering_message.content).present?

    contact&.email.blank?
  end

  def capture_typed_email!(message)
    return unless eligible_for_email_capture?(message)

    contact = message_contact(message)
    return if contact.blank?

    email = candidate_email(message, contact)
    return if email.blank?

    update_contact_email(contact, email, message.account)
  end

  def eligible_for_email_capture?(message)
    message.incoming? && !message.form? && message.submitted_values.blank?
  end

  def message_contact(message)
    (message.sender.is_a?(Contact) ? message.sender : nil) || message.conversation&.contact
  end

  def candidate_email(message, contact)
    email = self.class.extract_email(message.content)
    return nil if email.blank? || contact.email.to_s.casecmp?(email)

    email
  end

  def update_contact_email(contact, email, message_account)
    account = message_account || contact.account
    return if account.contacts.where.not(id: contact.id).exists?(email: email)

    contact.update(email: email)
  end

  def post_form_if_needed!(triggering_message: nil)
    return nil if conversation.blank?

    contact = conversation.contact
    return nil if contact.blank?

    missing_fields = []
    missing_fields << 'name' if self.class.missing_name?(contact)
    missing_fields << 'email' if self.class.missing_email?(contact, triggering_message: triggering_message)

    return nil if missing_fields.empty?
    return nil unless guard_form_posting!(missing_fields)

    post_form_message!(missing_fields)
  end

  def handle_form_submission!(message)
    return false unless form_active?(message)

    submitted = message.content_attributes&.dig('submitted_values')
    return false if submitted.blank?

    return false unless claim_submission_processing(message)

    contact = message.conversation.contact
    return false if contact.blank?

    save_submitted_contact_details(contact, submitted)
    post_acknowledgement_reply!(message)

    true
  end

  def form_active?(message)
    return false unless form_message?(message)
    return false if message.content_attributes&.dig('contact_details_saved') == true
    return false if message_expired?(message)
    return false if message.conversation&.resolved?

    true
  end

  def message_expired?(message)
    message.created_at.present? && message.created_at < GUARD_TTL.seconds.ago
  end

  def form_message?(message)
    return false unless message.form? || message.content_type == 'form'

    message.content_attributes&.dig('type') == 'contact_capture' || message.content == FORM_TEXT
  end

  # The guard only stops one handoff from posting the form twice. Clearing it when
  # the handoff ends lets the next handoff ask again if details are still missing.
  def reset_form_guard!
    [%w[name], %w[email], %w[name email]].each { |fields| Redis::Alfred.delete(guard_key(fields)) }
  end

  private

  def guard_key(missing_fields)
    "captain:contact_form:#{conversation.id}:#{missing_fields.sort.join('_')}"
  end

  def guard_form_posting!(missing_fields)
    key = guard_key(missing_fields)
    result = Redis::Alfred.set(key, 1, nx: true, ex: GUARD_TTL)
    return false if result.blank? || result == false

    true
  rescue StandardError => e
    Rails.logger.warn("[ContactCaptureService] Guard check error: #{e.message}")
    true
  end

  def post_form_message!(missing_fields)
    sender = assistant || conversation.inbox&.captain_assistant
    additional_attrs = sender&.name.present? ? { 'agent_name' => sender.name } : {}

    conversation.messages.create!(
      self.class.form_payload(missing_fields).merge(
        message_type: :outgoing,
        account_id: conversation.account_id,
        inbox_id: conversation.inbox_id,
        sender: sender,
        additional_attributes: additional_attrs,
        preserve_waiting_since: true
      )
    )
  end

  def claim_submission_processing(message)
    message.with_lock do
      return false if message.content_attributes&.dig('contact_details_saved')

      attrs = (message.content_attributes || {}).to_h.deep_dup
      attrs['contact_details_saved'] = true
      message.update_columns(content_attributes: attrs) # rubocop:disable Rails/SkipsModelValidations
      true
    end
  end

  def save_submitted_contact_details(contact, submitted)
    name_val = extract_submitted_value(submitted, 'name')
    email_val = extract_submitted_value(submitted, 'email')

    updates = {}
    updates[:name] = name_val.strip if name_val.present?

    if email_val.present?
      clean_email = email_val.strip.downcase
      account = contact.account
      updates[:email] = clean_email unless account.contacts.where.not(id: contact.id).exists?(email: clean_email)
    end

    contact.update(updates) if updates.present?
  end

  def extract_submitted_value(submitted, field_name)
    return extract_value_from_array(submitted, field_name) if submitted.is_a?(Array)
    return submitted[field_name] || submitted[field_name.to_sym] if submitted.is_a?(Hash)

    nil
  end

  def extract_value_from_array(submitted, field_name)
    item = submitted.find { |s| s['name'].to_s == field_name || s[:name].to_s == field_name }
    item ? (item['value'] || item[:value]) : nil
  end

  def post_acknowledgement_reply!(message)
    sender = assistant || message.conversation.inbox&.captain_assistant
    additional_attrs = sender&.name.present? ? { 'agent_name' => sender.name } : {}

    message.conversation.messages.create!(
      message_type: :outgoing,
      account_id: message.account_id,
      inbox_id: message.inbox_id,
      sender: sender,
      content: ACKNOWLEDGEMENT_TEXT,
      additional_attributes: additional_attrs,
      preserve_waiting_since: true
    )
  end
end
