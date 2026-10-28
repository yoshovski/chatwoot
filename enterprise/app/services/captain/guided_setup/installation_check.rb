# Tells the owner whether the chat widget runs on their website, and if not, why: the widget never reported a visit
# and the page either can't be read or doesn't contain this inbox's script.
class Captain::GuidedSetup::InstallationCheck
  MAX_BYTES = 1.megabyte

  def initialize(inbox)
    @inbox = inbox
    @channel = inbox.channel
  end

  def perform
    return 'installed' if widget_reported?
    return 'unreachable' if channel.website_url.blank?

    page_has_script? ? 'script_found' : 'not_found'
  rescue SafeFetch::Error
    'unreachable'
  end

  private

  attr_reader :inbox, :channel

  def widget_reported?
    ContactInbox.where(inbox_id: inbox.id).where.not(website_activity: {}).exists? || inbox.conversations.exists?
  end

  def page_has_script?
    SafeFetch.fetch(website_url, validate_content_type: false, max_bytes: MAX_BYTES) do |result|
      result.tempfile.read.include?(channel.website_token)
    end
  end

  def website_url
    url = channel.website_url.strip
    url.match?(%r{\Ahttps?://}i) ? url : "https://#{url}"
  end
end
