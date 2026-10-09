module Enterprise::ActivityMessageHandler
  def automation_status_change_activity_content
    return super unless Current.executed_by.instance_of?(Captain::Assistant)

    locale = Current.executed_by.account.locale
    key = captain_activity_key
    return unless key

    I18n.t(key, user_name: Current.executed_by.name, reason: captain_status_reason, locale: locale)
  end

  private

  def activity_message_owner(user_name)
    captain_assistant_name(user_name) || super
  end

  def priority_change_activity(user_name)
    super(captain_assistant_name(user_name) || user_name)
  end

  def captain_assistant_name(user_name)
    Current.executed_by.name if user_name.blank? && Current.executed_by.instance_of?(Captain::Assistant)
  end

  def captain_status_reason
    captain_activity_reason.presence
  end

  def captain_activity_key
    return captain_resolved_activity_key if resolved?
    return captain_open_activity_key if open?
  end

  def captain_resolved_activity_key
    return 'conversations.activity.captain.resolved_by_tool' if captain_activity_reason_type == :tool && captain_status_reason.present?
    return 'conversations.activity.captain.resolved_with_reason' if captain_status_reason.present?

    'conversations.activity.captain.resolved'
  end

  def captain_open_activity_key
    return 'conversations.activity.captain.open_with_reason' if captain_status_reason.present?

    'conversations.activity.captain.open'
  end
end
