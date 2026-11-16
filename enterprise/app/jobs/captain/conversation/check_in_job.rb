# frozen_string_literal: true

# Kept so jobs queued before widget attention shipped drain without sending anything.
# The widget now presents website check-ins itself (Widget::AttentionService).
class Captain::Conversation::CheckInJob < ApplicationJob
  queue_as :low

  def perform(_conversation_id, _assistant_id); end
end
