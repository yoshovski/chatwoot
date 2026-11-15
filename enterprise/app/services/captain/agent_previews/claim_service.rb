# "Send me the full agent" (T27): an email turns a public agent preview into a real account. It is a public signup
# like the sign-up form (consent, trial per website, the T11 checks), without a password: the confirmation email is the
# magic link, and confirming signs the person in. The preview's website is attached now; its import starts only when the
# email is confirmed (User#after_confirmation → Signup::StartWebsiteImportJob), so an unconfirmed address can't make
# the app crawl a site. The guided setup then opens on the Test step (T14).
class Captain::AgentPreviews::ClaimService
  pattr_initialize [:token!, :preview!, :email!, :ip, :locale]

  class AlreadyClaimed < StandardError; end

  def perform
    raise AlreadyClaimed unless Captain::AgentPreviews::Store.claim!(token)

    user, account = begin
      I18n.with_locale(locale.presence || I18n.default_locale) { build_account }
    rescue StandardError
      Captain::AgentPreviews::Store.release!(token)
      raise
    end
    account.update!(custom_attributes: account.custom_attributes.merge('website' => preview['url'], 'signup_source' => 'agent_preview'))
    user
  end

  private

  def build_account
    AccountBuilder.new(
      account_name: preview['domain'], email: email, user_password: password, user_full_name: email.split('@').first.to_s.first(50),
      signup: true, signup_details: { ip: ip, signup_method: 'agent_preview' }
    ).perform
  end

  # Never shown or sent: the person signs in with the confirmation link and can set a password later.
  def password = "#{SecureRandom.base58(24)}aA1!"
end
