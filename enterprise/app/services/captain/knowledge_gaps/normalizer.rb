# Groups customer questions without an LLM: case, punctuation, emoji and common filler words don't make a new gap.
module Captain::KnowledgeGaps::Normalizer
  FILLER_WORDS = %w[
    hi hello hey hola ciao please pls thanks thank thx you can could would i me my we our the a an
  ].to_set.freeze

  def self.call(text)
    words = text.to_s.downcase.delete("'’").gsub(/[^[:alnum:][:space:]]/, ' ').split
    meaningful = words.reject { |word| FILLER_WORDS.include?(word) }
    (meaningful.presence || words).join(' ')
  end
end
