class Enterprise::Billing::AutoTopUpJob < ApplicationJob
  queue_as :default

  def perform(account_id)
    account = Account.find_by(id: account_id)
    Enterprise::Billing::TopUpService.new(account: account).auto if account
  end
end
