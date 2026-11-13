# A public signup (T11): consent to the terms, where it came from, and whether it got the trial. One trial per website
# domain: the domain of a business email address (email_domain, nil for free mail), or the website the account sets
# later in onboarding or settings (website_domain). When the account is deleted the row keeps only the domains and the
# trial decision, so deleting an account and signing up again does not earn a second trial.
class AccountSignup < ApplicationRecord
  METHODS = %w[email google api].freeze

  belongs_to :account, optional: true
  belongs_to :user, optional: true

  validates :signup_method, inclusion: { in: METHODS }

  scope :with_trial, -> { where(trial_granted: true) }

  # A Google signup is confirmed from the start; an email signup gets its welcome when it confirms (User).
  after_create_commit -> { Signup::WelcomeJob.perform_later(self) }, if: -> { user&.confirmed? }

  # The domain that identifies the business: nil for free mail (gmail.com, outlook.com, …) and disposable addresses,
  # which many unrelated people share.
  def self.business_domain(email)
    Companies::BusinessEmailDetectorService.new(email).perform ? email.split('@').last.downcase : nil
  end

  # "https://www.Shop.example/path" → "shop.example".
  def self.website_domain(url)
    url = url.to_s.strip
    return if url.blank?

    host = URI.parse(url.match?(%r{\A[a-z][a-z0-9+.-]*://}i) ? url : "https://#{url}").host
    host&.downcase&.delete_prefix('www.').presence
  rescue URI::InvalidURIError
    nil
  end

  # Whether another signup already got a trial for this domain.
  def self.trial_used_for?(domain, except: nil)
    return false if domain.blank?

    scope = with_trial.where('email_domain = :domain OR website_domain = :domain', domain: domain)
    scope = scope.where.not(id: except.id) if except&.persisted?
    scope.exists?
  end

  def trial_domains
    [email_domain, website_domain].compact.uniq
  end

  def trial_domain_used?
    trial_domains.any? { |domain| self.class.trial_used_for?(domain, except: self) }
  end

  # The person who signed up has not confirmed their email (no AI reply until they do).
  def email_unconfirmed?
    user.present? && !user.confirmed?
  end
end
