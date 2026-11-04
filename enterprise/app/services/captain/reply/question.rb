# Question sentences at the end of a reply text, in any script ("?", "？", "؟"). A sentence ends at ".", "!", "?" or
# "…" before a space (not the last dot of "e.g." or "i.e."), at a CJK or Arabic full stop or question mark, or at a
# line break, so "3.5" or "e.g." inside a question stay in it.
module Captain::Reply::Question
  QUESTION_END = /[?？؟]\s*\z/
  SENTENCE_END = /(?<!\.[[:alpha:]])\.(?=\s)|[!?…](?=\s)|[。！？؟\n]/

  def self.trailing?(text) = text.to_s.match?(QUESTION_END)

  # The text without the question sentences it ends with (blank when it is only questions).
  def self.without_trailing(text)
    text = text.to_s
    while trailing?(text)
      body = text.rstrip.chop
      boundary = body.rindex(SENTENCE_END)
      text = boundary ? body[0..boundary].rstrip : ''
    end
    text
  end
end
