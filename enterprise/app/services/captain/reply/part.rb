# One piece of a reply's prose. kind: :answer for the model's parts, :greeting for the AI welcome and :fallback for
# the empty-answer text. model_index is the model's own index (nil for the welcome and the fallback).
Captain::Reply::Part = Data.define(:text, :citation_indexes, :model_index, :kind) do
  def initialize(text:, citation_indexes: [], model_index: nil, kind: :answer) = super

  # The shape stored in the message's captain_v2_response_parts attribute.
  def to_response_part = { 'text' => text, 'citation_indexes' => citation_indexes }
end
