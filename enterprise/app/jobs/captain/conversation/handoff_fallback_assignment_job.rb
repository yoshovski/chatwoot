# frozen_string_literal: true

class Captain::Conversation::HandoffFallbackAssignmentJob < ApplicationJob
  queue_as :default

  def perform(conversation, assistant)
    return unless eligible?(conversation, assistant)

    conversation.with_lock do
      return unless eligible?(conversation, assistant)

      assign_fallback(conversation, assistant)
    end
  end

  private

  def eligible?(conversation, assistant)
    return false if conversation.blank? || assistant.blank?
    return false unless conversation.account&.feature_enabled?('captain_integration_v2')
    return false unless conversation.open?
    return false if conversation.assignee_id.present?

    true
  end

  def assign_fallback(conversation, assistant)
    fallback_agent = assistant.handoff_fallback_agent
    if fallback_agent.present? && conversation.inbox.inbox_members.exists?(user_id: fallback_agent.id)
      conversation.update!(assignee: fallback_agent)
      return
    end

    fallback_team = assistant.handoff_fallback_team
    return if fallback_team.blank?

    conversation.update!(team: fallback_team)
  end
end
