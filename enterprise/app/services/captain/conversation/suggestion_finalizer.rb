# Deterministic finalizer for Captain suggested reply buttons at the composition boundary.
# Normalizes, deduplicates (including post-truncation label collisions), filters proactive
# cancellation/refund prompts unless contextually relevant, and fills up to max_suggested_replies
# from the assistant's source-backed published brief pool without extra model or network calls.
class Captain::Conversation::SuggestionFinalizer
  BARE_LABELS = /\A(?:yes|no|ok|okay|sure|learn\s+more|continue|more|next)\z/i
  PROACTIVE_EXCLUSION_PATTERN = /\b(?:cancel(?:lation|ling)?|refunds?|money\s+back|close\s+(?:my\s+)?account|
                                    delete\s+(?:my\s+)?account|terminate\s+(?:my\s+)?account)\b/xi
  BLOCKING_INPUT_PATTERN = /\b(?:please\s+(?:share|provide|enter|send|type|give\s+me|tell\s+me)|what\s+is\s+your|
                                could\s+you\s+(?:share|provide|tell\s+me))\s+(?:(?:your|the|an?)\s+)?
                            (?:order\s+number|email(?:\s+address)?|phone\s+number|tracking\s+number|account\s+id|
                               company(?:\s+name)?|country|audience(?:\s+size)?|subscriber(?:s|\s+count)?|
                               (?:full\s+)?name(?:\s+and\s+email)?|quote\s+details)\b/xi

  def initialize(assistant:, response:, run_result: nil, **options)
    @assistant = assistant
    @response = response
    @run_result = run_result
    @customer_message = options[:customer_message]
    @suppress_suggestions = options.fetch(:suppress_suggestions, false)
    @has_closing_question = options.fetch(:has_closing_question, false)
  end

  def perform
    raw = raw_suggestions
    target = @assistant.max_suggested_replies
    suppression = suppression_reason(raw)
    if suppression
      record_metrics(requested: target, proposed: raw.size, cleaned: 0, fallback: 0, delivered: 0,
                     mode: suppression[:mode], reason: suppression[:reason])
      return []
    end

    cleaned = deduplicate_and_filter(raw) { |item| clean_item(item) }.take(target)
    fallback_items = fill_from_fallback(cleaned, target - cleaned.size)
    final = merge_with_kinds(cleaned, fallback_items)
    reason = final.size < target ? 'insufficient_fallback_pool' : nil
    mode = fallback_items.any? ? 'filled' : 'model'
    record_metrics(requested: target, proposed: raw.size, cleaned: cleaned.size, fallback: fallback_items.size,
                   delivered: final.size, mode: mode, reason: reason)
    final
  end

  private

  def raw_suggestions
    return [] unless @response.is_a?(Hash)

    Array(@response['suggested_replies'])
  end

  def suppression_reason(raw)
    return { mode: 'disabled', reason: 'setting_disabled' } if explicitly_disabled?
    return { mode: 'suppressed', reason: 'handoff_or_waiting' } if @suppress_suggestions
    return { mode: 'suppressed', reason: 'handoff_requested' } if handoff_requested?

    blocking_input_suppression(raw)
  end

  def handoff_requested?
    @response.is_a?(Hash) && @response['handoff_requested'] == true
  end

  def blocking_input_suppression(raw)
    return unless raw.empty?
    return { mode: 'blocking_input', reason: 'open_question_without_model_choices' } if @has_closing_question
    return { mode: 'blocking_input', reason: 'free_text_input_required' } if blocking_input_prompt?

    nil
  end

  def explicitly_disabled?
    config = @assistant.config.to_h
    config.key?('suggested_replies') && !@assistant.suggested_replies?
  end

  def blocking_input_prompt?
    return true if @response.is_a?(Hash) && @response['suggestion_mode'] == 'blocking_input'

    prose_text.match?(BLOCKING_INPUT_PATTERN)
  end

  def deduplicate_and_filter(items, existing: [])
    seen_titles = existing.to_set { |item| canonical_key(item['title']) }
    seen_values = existing.to_set { |item| canonical_key(item['value']) }
    customer_norm = canonical_key(customer_text)

    items.filter_map do |item|
      cleaned = yield(item)
      cleaned if valid_unique_suggestion?(cleaned, seen_titles, seen_values, customer_norm)
    end
  end

  def valid_unique_suggestion?(cleaned, seen_titles, seen_values, customer_norm)
    return false unless cleaned && !unrequested_cancellation?(cleaned['title'], cleaned['value'])

    title_key = canonical_key(cleaned['title'])
    val_key = canonical_key(cleaned['value'])
    return false if duplicate_or_echoed?(title_key, val_key, customer_norm)

    seen_titles.add?(title_key).present? && seen_values.add?(val_key).present?
  end

  def duplicate_or_echoed?(title_key, val_key, customer_norm)
    title_key.blank? || val_key.blank? || (customer_norm.present? && val_key == customer_norm)
  end

  def clean_item(item)
    label, message = item.is_a?(Hash) ? item.values_at('label', 'message') : [item, nil]
    label = label.to_s.strip
    return if label.blank?

    raw_msg = message.to_s.strip
    return if label.match?(BARE_LABELS) && (raw_msg.blank? || raw_msg.match?(BARE_LABELS))

    final_message = (raw_msg.presence || label).first(Captain::ResponseSchema::SUGGESTION_MESSAGE_MAX_LENGTH)
    final_label = label.truncate(Captain::ResponseSchema::SUGGESTION_LABEL_MAX_LENGTH, separator: ' ')
    { 'title' => final_label, 'value' => final_message }
  end

  def fill_from_fallback(existing, needed)
    return [] if needed <= 0

    pool = authorized_fallback_candidates
    return [] if pool.empty?

    deduplicate_and_filter(ranked_fallback_pool(pool), existing: existing) do |candidate|
      clean_item('label' => candidate['title'], 'message' => candidate['message'])
    end.take(needed)
  end

  def merge_with_kinds(model_items, fallback_items)
    return model_items if fallback_items.empty?
    return fallback_items if model_items.empty?
    return model_items + fallback_items unless @has_closing_question

    model_items.map { |item| item.merge('kind' => 'choice') } +
      fallback_items.map { |item| item.merge('kind' => 'follow_up') }
  end

  def authorized_fallback_candidates
    brief = @assistant.knowledge_brief
    return [] unless @assistant.config['knowledge_brief_enabled'] == true && brief&.usable?(brief.published)

    brief.usable_suggestion_candidates(brief.published)
  end

  KIND_RANK = { 'offering' => 0, 'category' => 1 }.freeze

  def ranked_fallback_pool(candidates)
    cited_doc_ids = turn_document_ids
    reply_norm = canonical_key(prose_text)
    candidates.sort_by.with_index do |candidate, idx|
      [candidate_cited_rank(candidate, cited_doc_ids), candidate_mentioned_rank(candidate, reply_norm),
       KIND_RANK.fetch(candidate['target_kind'], 2), idx]
    end
  end

  def candidate_cited_rank(candidate, cited_doc_ids)
    cited_doc_ids.any? && Array(candidate['document_ids']).map(&:to_i).intersect?(cited_doc_ids) ? 0 : 1
  end

  def candidate_mentioned_rank(candidate, reply_norm)
    reply_norm.present? && reply_norm.include?(canonical_key(candidate['title'])) ? 1 : 0
  end

  def turn_document_ids
    state = @run_result&.context&.dig(:state) || {}
    cw_docs = Array(state.dig(:cw_metadata, :document_ids)).map(&:to_i)
    citation_docs = state.fetch(Captain::Assistant::CITATION_DETAILS_STATE_KEY, {}).values.filter_map { |d| d[:document_id]&.to_i }
    (cw_docs | citation_docs).uniq
  end

  def unrequested_cancellation?(title, value)
    return false unless "#{title} #{value}".match?(PROACTIVE_EXCLUSION_PATTERN)

    context_text = "#{customer_text} #{prose_text}"
    !context_text.match?(PROACTIVE_EXCLUSION_PATTERN)
  end

  def customer_text
    return @customer_message.content.to_s if @customer_message.respond_to?(:content)

    @customer_message.to_s
  end

  def prose_text
    @prose_text ||= Captain::Assistant::ResponseParts.from_response(@response).plain_text.to_s
  end

  def canonical_key(text)
    text.to_s.downcase.gsub(/[^[:alnum:]]+/, ' ').strip
  end

  def record_metrics(**metrics_data)
    brief = @assistant.knowledge_brief
    metrics = metrics_data.merge(snapshot_revision: brief&.published&.dig('revision'))
    if @run_result.respond_to?(:context) && @run_result.context.is_a?(Hash) && @run_result.context[:state].is_a?(Hash)
      @run_result.context[:state][:suggestion_metrics] = metrics
    end
    Rails.logger.info "[Captain][Suggestions] assistant_id=#{@assistant.id} metrics=#{metrics.to_json}"
  end
end
