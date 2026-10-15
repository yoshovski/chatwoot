class BackfillConversationsAiParticipatedAt < ActiveRecord::Migration[7.1]
  AI_SENDER_TYPES = "'AgentBot', 'Captain::Assistant'".freeze

  # Backfills from the three places AI participation is already recorded:
  # the current AI assignee, messages an AI sent, and bot handoff reporting events.
  def up
    backfill_current_ai_assignees
    backfill_from_ai_messages
    backfill_from_bot_handoffs
  end

  def down
    # The column is dropped by the previous migration's down.
  end

  private

  def backfill_current_ai_assignees
    execute(<<~SQL.squish)
      UPDATE conversations SET ai_participated_at = created_at
      WHERE ai_participated_at IS NULL AND assignee_agent_bot_id IS NOT NULL
    SQL
  end

  def backfill_from_ai_messages
    execute(<<~SQL.squish)
      UPDATE conversations SET ai_participated_at = ai_messages.first_at
      FROM (
        SELECT conversation_id, MIN(created_at) AS first_at FROM messages
        WHERE sender_type IN (#{AI_SENDER_TYPES}) AND message_type = 1
        GROUP BY conversation_id
      ) ai_messages
      WHERE conversations.id = ai_messages.conversation_id AND conversations.ai_participated_at IS NULL
    SQL
  end

  def backfill_from_bot_handoffs
    execute(<<~SQL.squish)
      UPDATE conversations SET ai_participated_at = handoffs.first_at
      FROM (
        SELECT conversation_id, MIN(created_at) AS first_at FROM reporting_events
        WHERE name = 'conversation_bot_handoff' AND conversation_id IS NOT NULL
        GROUP BY conversation_id
      ) handoffs
      WHERE conversations.id = handoffs.conversation_id AND conversations.ai_participated_at IS NULL
    SQL
  end
end
