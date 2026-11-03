# Writes each bubble's text in the channel's form: sources under the bubble on the widget, as links in email and as
# lines elsewhere. The welcome becomes its own segment that opens the first bubble.
class Captain::Reply::Policies::Channel < Captain::Reply::Policies::Base
  def apply
    workspace.segments = workspace.segments.flat_map { |segment| segment.prose? ? written(segment) : [segment] }
  end

  private

  def written(segment)
    text = workspace.text(segment)
    greeting, *rest = segment.parts
    return [segment.with(text: text)] unless greeting&.kind == :greeting
    return [segment.with(kind: 'greeting', text: text)] if rest.empty?

    [Captain::Reply::Segment.new(kind: 'greeting', text: greeting.text, parts: [greeting], attach: :next),
     segment.with(text: text, parts: rest)]
  end
end
