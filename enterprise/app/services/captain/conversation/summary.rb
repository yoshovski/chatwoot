# What the AI knows about a conversation: status, what the customer wants, details, the next step, the lead and
# actions done. Kept on the conversation, so the thread, the conversation list and the handoff notifications read it
# without private notes. Written on handoff, lead capture, a confirmed action and resolve.
class Captain::Conversation::Summary
  KEY = 'captain_summary'.freeze
  STATUSES = %w[handed_off lead action resolved].freeze
  # The handoff prompt answers in "Wants: / Details: / Next:" lines.
  LINE_FIELDS = { 'wants' => 'wants', 'details' => 'details', 'next' => 'next_step' }.freeze
  LINE = /\A\s*(wants|details|next)\s*:\s*(.+)\z/i
  MAX_ACTIONS = 10

  attr_reader :conversation

  def self.read(conversation)
    conversation.additional_attributes.to_h[KEY]
  end

  # "Wants: x\nDetails: y\nNext: z" → { 'wants' => 'x', 'details' => 'y', 'next_step' => 'z' }. Anything else is ignored.
  def self.parse(text)
    text.to_s.lines.each_with_object({}) do |line, fields|
      match = line.strip.match(LINE)
      fields[LINE_FIELDS[match[1].downcase]] = match[2].strip if match
    end
  end

  def initialize(conversation)
    @conversation = conversation
  end

  # Takes the conversation lock; callers that already hold it merge `merged_attributes` into their own update.
  def update!(changes)
    conversation.with_lock do
      conversation.update!(additional_attributes: merged_attributes(changes))
    end
  end

  def merged_attributes(changes)
    attributes = conversation.additional_attributes.to_h
    attributes.merge(KEY => attributes[KEY].to_h.merge(changes.stringify_keys, 'updated_at' => Time.current.iso8601))
  end

  def record_handoff!(note_content:, reason:)
    fields = if reason.present?
               { 'reason' => note_content.to_s.lines.drop(1).join.strip }
             else
               self.class.parse(note_content).merge('reason' => nil)
             end
    # Runs inside the handoff's own lock (or deliberately without one on the legacy path), so it takes none.
    conversation.update!(additional_attributes: merged_attributes({ 'status' => 'handed_off' }.merge(fields)))
    # The agent's own reason is not the Wants / Details / Next summary: write that one in the background.
    Captain::Conversation::SummaryJob.perform_later(conversation, 'handed_off') if reason.present?
  end

  def record_action!(title:, outcome:)
    action = { 'title' => title, 'outcome' => outcome.to_s, 'at' => Time.current.iso8601 }
    conversation.with_lock do
      actions = (self.class.read(conversation).to_h['actions'] || []) + [action]
      conversation.update!(additional_attributes: merged_attributes('status' => 'action', 'actions' => actions.last(MAX_ACTIONS)))
    end
  end
end
