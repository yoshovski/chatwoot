# The ordered segments of one reply. payloads turns them into the message payloads the chat job posts: a segment
# with attach: :next becomes part of the next bubble (the AI welcome opens the answer bubble on email and other
# channels; on the widget it is a bubble of its own). The next segment's text already holds the attached prose, so
# merging adds the attached parts and kinds.
class Captain::Reply::Plan
  SEGMENT_KINDS_KEY = 'captain_segment_kinds'.freeze

  attr_accessor :segments

  def initialize(segments)
    @segments = segments
  end

  # segment_kinds: false leaves out captain_segment_kinds, for callers that only show the reply.
  def payloads(segment_kinds: true)
    bubbles.map do |attached, segment|
      payload = segment.payload(parts: segment.parts && (attached.flat_map(&:parts) + segment.parts))
      next payload unless segment_kinds

      kinds = [*attached, segment].map(&:kind)
      payload.merge(additional_attributes: payload[:additional_attributes].to_h.merge(SEGMENT_KINDS_KEY => kinds))
    end
  end

  # [attached segments, segment] per message.
  def bubbles
    attached = []
    segments.each_with_object([]) do |segment, bubbles|
      next attached << segment if segment.attach == :next

      bubbles << [attached, segment]
      attached = []
    end
  end

  def kinds = segments.map(&:kind)
end
