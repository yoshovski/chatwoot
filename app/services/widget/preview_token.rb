# Signs the short-lived link the dashboard uses to load the real widget as a settings preview. An iframe can't send the
# dashboard's auth headers, so the token is the only credential the preview page gets.
class Widget::PreviewToken
  EXPIRY = 15.minutes

  def self.generate(inbox:, user:)
    expires_at = EXPIRY.from_now
    token = verifier.generate({ inbox_id: inbox.id, user_id: user.id }, expires_at: expires_at, purpose: :widget_preview)
    { token: token, expires_at: expires_at.to_i }
  end

  # The signed payload, or nil when the token is missing, expired or tampered with.
  def self.verify(token)
    verifier.verified(token.to_s, purpose: :widget_preview)&.with_indifferent_access
  end

  def self.verifier
    Rails.application.message_verifier(:widget_preview)
  end
end
