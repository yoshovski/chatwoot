# Writes each bubble's text in the channel's form: sources under the bubble on the widget, as links in email and as
# lines elsewhere. The welcome becomes its own segment: its own bubble before the answer on the widget, the start of
# the first bubble on email and other channels (one message there). Until the early welcome (CWAI-137 follow-up) the
# widget also opened the answer bubble with it; that decision was reversed.
class Captain::Reply::Policies::Channel < Captain::Reply::Policies::Base
  def apply
    workspace.segments = workspace.segments.flat_map { |segment| segment.prose? ? written(segment) : [segment] }
  end

  private

  def written(segment)
    greeting, *rest = segment.parts
    return [segment.with(text: workspace.text(segment))] unless greeting&.kind == :greeting
    return [segment.with(kind: 'greeting', text: workspace.text(segment))] if rest.empty?
    return [greeting_bubble(segment, greeting), segment.with(text: workspace.format(rest, media: segment.media), parts: rest)] if context.widget?

    [Captain::Reply::Segment.new(kind: 'greeting', text: greeting.text, parts: [greeting], attach: :next),
     segment.with(text: workspace.text(segment), parts: rest)]
  end

  def greeting_bubble(segment, greeting)
    Captain::Reply::Segment.new(kind: 'greeting', text: workspace.format([greeting], media: false), parts: [greeting], content_type: 'text',
                                additional_attributes: segment.additional_attributes.to_h.slice(:agent_name))
  end
end
