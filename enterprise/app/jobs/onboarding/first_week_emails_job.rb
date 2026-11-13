# Sends the first-week emails that are due (T15). Hourly, so day 1, 3 and 7 arrive near the hour the account was made.
class Onboarding::FirstWeekEmailsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Onboarding::FirstWeekEmailsService.candidates.includes(:account, :user).find_each do |signup|
      Onboarding::FirstWeekEmailsService.new(signup).deliver_due
    rescue StandardError => e
      ChatwootExceptionTracker.new(e, account: signup.account).capture_exception
    end
  end
end
