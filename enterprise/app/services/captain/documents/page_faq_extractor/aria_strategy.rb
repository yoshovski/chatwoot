class Captain::Documents::PageFaqExtractor::AriaStrategy
  def initialize(extractor, node, doc)
    @extractor = extractor
    @node = node
    @doc = doc
  end

  def extract
    faqs = []
    @node.css('[aria-controls]').each do |trigger|
      next if @extractor.consumed?(trigger)

      candidate = build_candidate(trigger)
      next unless candidate

      claim_elements(trigger, candidate[:elements])
      faqs << candidate
    end
    faqs
  end

  private

  def build_candidate(trigger)
    target_id = trigger['aria-controls']
    return nil if target_id.blank?

    panel = @doc.at_xpath(%(.//*[@id="#{target_id.gsub('"', '\\"')}"]))
    return nil if panel.blank? || @extractor.consumed?(panel)

    q_text = trigger.text.strip
    return nil if q_text.blank?

    a_md = @extractor.node_to_markdown(panel)
    return nil if a_md.blank?

    removal_trigger = trigger_removal_target(trigger)
    {
      question: q_text,
      answer: a_md,
      node: trigger,
      elements: [removal_trigger, panel]
    }
  end

  def trigger_removal_target(trigger)
    parent = trigger.parent
    if parent && parent.name =~ /\Ah[1-6]\z/ && parent.text.strip == trigger.text.strip
      parent
    else
      trigger
    end
  end

  def claim_elements(trigger, elements)
    @extractor.consume!(trigger)
    elements.each { |el| @extractor.consume!(el) }
  end
end
