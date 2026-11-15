# Starts the website import of an account claimed from chatoctave.com's agent preview (T27), once its email is confirmed.
# The import (AI agent, instant agent, discovery) is Enterprise; a CE build has nothing to start.
class Signup::StartWebsiteImportJob < ApplicationJob
  queue_as :high
  discard_on ActiveRecord::RecordNotFound

  def perform(account_id)
    account = Account.find(account_id)
    url = account.custom_attributes['website']
    starter = 'Captain::GuidedSetup::WebsiteStarter'.safe_constantize
    return if url.blank? || starter.nil?

    starter.new(account, url).perform
  end
end
