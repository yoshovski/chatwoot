# The one entry point for widget attention: sounds, question cues and the "anything else?" check-in.
# The contact-inbox lock serializes all tabs and conversations of a visitor; each claim is recorded once
# per reply, so a cue is never replayed after a reload, a second tab or a reconnect. Nothing here posts a Message.
class Widget::AttentionService
  SOUND_COOLDOWN = 30.seconds
  CUE_COOLDOWN = 3.minutes
  MAX_QUESTIONS = 2
  REPLY_LIFETIME = 5.minutes
  ACKNOWLEDGEMENTS = %w[presented dismissed expired].freeze

  def initialize(contact_inbox:, conversation:)
    @contact_inbox = contact_inbox
    @conversation = conversation
  end

  def perform(kind:, message_id: nil, event_id: nil)
    @contact_inbox.with_lock do
      @session = WidgetAttentionSession.for(@contact_inbox)
      handle(kind, message_id, event_id)
    end
  end

  private

  def handle(kind, message_id, event_id)
    return acknowledge(kind, event_id) if ACKNOWLEDGEMENTS.include?(kind)

    case kind
    when 'activity' then @session.record_activity!
    when 'snooze' then @session.update!(snoozed: true)
    else return @session.active? ? @conversation.with_lock { claim(kind, message_id) } : nil
    end
    nil
  end

  def claim(kind, message_id)
    @message = claimable_message(message_id)
    return unless @message && (kind == 'sound' ? sound_eligible? : idle_eligible?(kind))

    reply_id = @message.additional_attributes['captain_reply_id'].presence || @message.id.to_s
    key = "#{@conversation.id}:#{reply_id}:#{kind == 'sound' ? 'sound' : 'idle'}"
    return if WidgetAttentionEvent.exists?(contact_inbox: @contact_inbox, event_key: key)

    event = WidgetAttentionEvent.create!(contact_inbox: @contact_inbox, conversation: @conversation, message: @message,
                                         event_key: key, kind: kind)
    update_budget(kind)
    { event_id: event.id, kind: kind, message_id: @message.id }
  end

  def claimable_message(message_id)
    message = @conversation.messages.outgoing.where(private: false).find_by(id: message_id)
    return if message.nil? || message.created_at < REPLY_LIFETIME.ago
    return if message.content_attributes['deleted'] || message.additional_attributes['captain_initiated'].present?

    message
  end

  def acknowledge(kind, event_id)
    event = WidgetAttentionEvent.find_by(id: event_id, contact_inbox: @contact_inbox, conversation: @conversation)
    open_statuses = kind == 'dismissed' ? %w[claimed presented] : %w[claimed]
    event.update!(status: kind) if event && open_statuses.include?(event.status)
    nil
  end

  def sound_eligible?
    @message.additional_attributes['campaign_id'].blank? && (@session.last_sound_at.nil? || @session.last_sound_at <= SOUND_COOLDOWN.ago)
  end

  def idle_eligible?(kind)
    return false if @session.snoozed? || cue_cooling_down?
    return false unless @conversation.pending? && latest_reply? && assistant_eligible?(kind)

    kind == 'check_in' ? check_in_available? : @session.question_count < MAX_QUESTIONS
  end

  # Captain supplies the semantic eligibility in the enterprise extension. Unknown intent stays quiet.
  def assistant_eligible?(_kind) = false

  def cue_cooling_down? = @session.last_cue_at.present? && @session.last_cue_at > CUE_COOLDOWN.ago

  def latest_reply?
    @message.additional_attributes['captain_reply_final'] == true &&
      @conversation.messages.where(private: false, message_type: [:incoming, :outgoing]).maximum(:id) == @message.id
  end

  # One check-in per conversation and per visit, whatever the visitor answers in between.
  def check_in_available?
    return false if @session.checked_in? || WidgetAttentionEvent.exists?(conversation: @conversation, kind: 'check_in')

    !@conversation.messages.outgoing.exists?(["additional_attributes ->> 'captain_initiated' = ?", 'check_in'])
  end

  def update_budget(kind)
    case kind
    when 'sound' then @session.update!(last_sound_at: Time.current)
    when 'question' then @session.update!(last_cue_at: Time.current, question_count: @session.question_count + 1)
    when 'check_in' then @session.update!(last_cue_at: Time.current, checked_in: true)
    end
  end
end

Widget::AttentionService.prepend_mod_with('Widget::AttentionService')
