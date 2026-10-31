# TODO: Wrap the schema lib under ai-agents
# So we can extend it as Agents::Schema
class Captain::ResponseSchema < RubyLLM::Schema
  # The handoff decision travels with the answer, like the [HANDOFF] marker in a
  # text reply, so a reply that promises a colleague can't skip the handoff.
  HANDOFF_REQUESTED_DESCRIPTION = 'True when this reply hands the conversation to a human colleague now, including whenever it tells ' \
                                  'the customer that a colleague or the team will continue, follow up, or confirm something. ' \
                                  'Also use the handoff tool when it is available, and say in the reply that a colleague will ' \
                                  'continue in this chat. False when no handoff is needed, or when you only ask whether the customer ' \
                                  'wants a human. Email follow-up intake and its contact form do not transfer the live chat: ' \
                                  'keep this false for request_lead_followup and a successful save_lead_details.'.freeze

  SEPARATE_PARTS_DESCRIPTION = 'Indexes of response parts (0 is the first) that must start a new message. List a part only when a ' \
                               'scenario step or instruction says to send it as a separate message; otherwise return an empty array.'.freeze

  WELCOME_DESCRIPTION = "This is your first reply in the conversation: one short, warm welcome sentence in the customer's language, " \
                        'without their name unless you know it. It is shown before your answer, so the response parts must not greet again.'.freeze

  SUGGESTION_LABEL_MAX_LENGTH = 50
  SUGGESTION_MESSAGE_MAX_LENGTH = 120

  array :response_parts,
        description: 'Ordered parts of the message to send to the user. Keep all customer-visible text within each part text field.',
        min_items: 1 do
    object do
      string :text, description: 'Customer-visible text without citation markers. Inline links must copy exact URLs from tool results.', min_length: 1
      array :citation_indexes,
            description: 'Source indexes of the tool results this text relies on. Use an empty array when none apply.' do
        integer minimum: 1
      end
    end
  end
  boolean :handoff_requested, description: HANDOFF_REQUESTED_DESCRIPTION

  SCHEMA_OPTIONS = %i[suggested_replies product_cards lead_capture separate_parts welcome].freeze

  # Options (all false by default): suggested_replies, product_cards, lead_capture,
  # separate_parts (an instruction or scenario asks to send something as a separate message) and
  # welcome (the first AI reply with the AI greeting on; a required field so the model can't skip it).
  def self.for(max_suggested_replies: 3, **options)
    flags = SCHEMA_OPTIONS.index_with { |key| options[key] == true }
    return self if flags.values.none?

    limit = (max_suggested_replies || 3).to_i.clamp(1, 5)
    @schema_cache ||= {}
    @schema_cache[[limit, flags]] ||= build_schema(limit: limit, **flags)
  end

  def self.build_schema(limit:, suggested_replies: false, product_cards: false, lead_capture: false, **shape)
    RubyLLM::Schema.create do
      name 'CaptainResponse'
      array :response_parts,
            description: 'Ordered parts of the message to send to the user. Keep all customer-visible text within each part text field.',
            min_items: 1 do
        object do
          string :text, min_length: 1,
                        description: 'Customer-visible text without citation markers. Inline links must copy exact URLs from tool results.'
          array :citation_indexes,
                description: 'Source indexes of the tool results this text relies on. Use an empty array when none apply.' do
            integer minimum: 1
          end
        end
      end
      boolean :handoff_requested, description: Captain::ResponseSchema::HANDOFF_REQUESTED_DESCRIPTION
      Captain::ResponseSchema.define_reply_shape(self, lead_capture: lead_capture, **shape)
      Captain::ResponseSchema.define_suggested_replies(self, limit) if suggested_replies
      Captain::ResponseSchema.define_product_handles(self) if product_cards
    end
  end

  def self.define_reply_shape(builder, lead_capture:, separate_parts: false, welcome: false)
    builder.string :welcome, description: WELCOME_DESCRIPTION, min_length: 1 if welcome
    if separate_parts
      builder.array :separate_parts, description: SEPARATE_PARTS_DESCRIPTION do
        integer minimum: 1
      end
    end
    define_lead_question(builder) if lead_capture
  end

  def self.define_lead_question(builder)
    builder.boolean :lead_qualification_question,
                    description: 'True only if this reply asks an optional business qualification question: use case, scale, company or country. ' \
                                 'False for an offer of email follow-up, collecting name/email after consent, or answering a customer question.'
  end

  def self.build_schema_with_suggestions(limit)
    build_schema(suggested_replies: true, limit: limit, product_cards: false)
  end

  def self.define_suggested_replies(builder, limit)
    builder.array :suggested_replies,
                  description: "Up to #{limit} relevant next steps or answers to your closing question, rendered as buttons. " \
                               'Include them with linked or illustrated answers too. Empty only for human handoff, frustration, ' \
                               'quote detail collection, required free-text input, or no supported next step.',
                  max_items: limit do
      object do
        string :label, description: 'Button text: 2 to 4 words.', max_length: SUGGESTION_LABEL_MAX_LENGTH
        string :message,
               description: "What the customer sends when clicking: the full question or request in the customer's voice and language, " \
                            'with specifics such as the order number or model.',
               max_length: SUGGESTION_MESSAGE_MAX_LENGTH
      end
    end
  end

  def self.define_product_handles(builder)
    builder.array :product_handles,
                  description: 'Up to 5 product handles to display as product cards, ordered best fit first. ' \
                               'Include only products returned by product tools in this turn. Empty array if none apply.',
                  max_items: 5 do
      string
    end
  end
end
