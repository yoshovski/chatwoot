module Enterprise::Message
  def self.prepended(base)
    base.class_eval do
      after_update_commit :invalidate_captain_conversation_memory, if: :captain_memory_source_changed?
      after_destroy_commit :invalidate_captain_conversation_memory

      has_one :call, class_name: 'Call', foreign_key: :message_id, dependent: :nullify, inverse_of: :message

      scope :with_call, -> { includes(call: [:contact, { inbox: :channel }]) }
      # Scheduling and freshness checks must share this scope so an email auto reply cannot cancel a pending response.
      scope :captain_response_triggering, lambda {
        incoming.joins(:inbox).where(
          "((messages.content_attributes #>> '{}')::jsonb -> 'email' ->> 'auto_reply') IS DISTINCT FROM 'true' OR " \
          "(messages.content_type != :incoming_email AND inboxes.channel_type != 'Channel::Email')",
          incoming_email: content_types[:incoming_email]
        )
      }
    end
  end

  def push_event_data
    data = super
    data[:call] = call.push_event_data if content_type == 'voice_call' && call.present?
    data
  end

  def captain_response_triggering?
    return incoming? && !auto_reply_email? unless persisted?

    self.class.captain_response_triggering.exists?(id: id)
  end

  def selected_option_text
    return nil unless input_select?

    item = first_submitted_option
    return nil unless item.is_a?(Hash)

    item = item.with_indifferent_access
    # Captain's suggestion buttons show a short title and send their value, the full question.
    return item[:value].presence || item[:title].presence if content_attributes&.dig('submit_value')

    item[:title].presence || item[:value].presence
  end

  private

  def captain_memory_source_changed?
    return true if saved_changes.keys.intersect?(%w[content content_attributes private])
    return false unless saved_change_to_additional_attributes?

    before, after = saved_change_to_additional_attributes
    key = Captain::Assistant::ResponseParts::MESSAGE_ATTRIBUTE_KEY
    before.to_h[key] != after.to_h[key]
  end

  def invalidate_captain_conversation_memory
    Captain::ConversationMemory.where(account_id: account_id, conversation_id: conversation_id)
                               .where('covered_message_id >= ?', id).find_each do |memory|
      memory.with_lock { memory.invalidate!(boundary_message_id: memory.boundary_message_id) }
    end
  end

  def first_submitted_option
    submitted = content_attributes&.dig('submitted_values')
    submitted.is_a?(Array) ? submitted.first : submitted
  end

  def reopen_resolved_conversation
    assistant = conversation.inbox.captain_assistant

    return super if assistant.blank? || conversation.inbox.external_bot_active?
    return conversation.open! unless assistant.engages?(conversation.contact, conversation)

    super
  end

  def mark_pending_conversation_as_open_for_human_response
    return unless captain_pending_conversation?
    return unless human_response?
    return if private?
    return if template_bootstrap_message?

    previous_user = Current.user
    previous_executed_by = Current.executed_by
    Current.user = nil
    Current.executed_by = nil

    begin
      conversation.ai_assignee = nil if conversation.ai_assignee_type == 'Captain::Assistant'
      conversation.open!
      return unless conversation.saved_change_to_status?

      create_captain_auto_open_activity_message
    ensure
      Current.user = previous_user
      Current.executed_by = previous_executed_by
    end
  end

  def captain_pending_conversation?
    return false unless conversation.pending?

    ::CaptainInbox.exists?(inbox_id: conversation.inbox_id)
  end

  def template_bootstrap_message?
    additional_attributes['template_params'].present? &&
      !conversation.messages.incoming.exists?
  end

  def create_captain_auto_open_activity_message
    ::Conversations::ActivityMessageJob.perform_later(
      conversation,
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :activity,
      content: I18n.t('conversations.activity.captain.auto_opened_after_agent_reply', locale: conversation.account.locale)
    )
  end
end
