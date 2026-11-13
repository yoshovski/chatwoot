# The account's public signup (T11): the trial follows its website, and the row outlives the account.
module AccountSignupTracking
  extend ActiveSupport::Concern

  included do
    has_one :account_signup, dependent: nil
    before_destroy :forget_signup_person
    after_update_commit :check_signup_website, if: -> { account_signup.present? && saved_change_to_custom_attributes? }
  end

  # A public signup whose person has not confirmed their email: the AI does not reply yet.
  def signup_email_unconfirmed?
    account_signup.present? && account_signup.email_unconfirmed?
  end

  private

  # Keeps the domains and the trial decision (one trial per domain), drops who it was.
  def forget_signup_person
    account_signup&.update!(account_id: nil, user_id: nil, email: nil, ip: nil)
  end

  def check_signup_website
    before, after = saved_change_to_custom_attributes.map { |attributes| attributes.to_h['website'] }
    Signup::TrialService.new(self).website_changed!(after) if after.present? && after != before
  end
end
