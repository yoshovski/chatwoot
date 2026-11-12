# Starts the knowledge import from the account's website. Creates the AI agent first when there is none, and remembers
# the URL as the account website (the chat widget inbox is created from it). The instant agent reads a few pages right
# away, so the agent can answer within seconds and gets its name, while the full discovery runs as before.
class Captain::GuidedSetup::WebsiteStarter
  def initialize(account, url)
    @account = account
    value = url.to_s.strip
    @url = value.match?(%r{\Ahttps?://}i) || value.blank? ? value : "https://#{value}"
  end

  def perform
    existing = Captain::GuidedSetup::State.new(account).assistant
    assistant = existing || create_assistant
    source = assistant.website_sources.find_by(url: Captain::Websites::UrlPolicy.normalize(url)) || start(assistant, name_agent: existing.nil?)
    remember_website(source.url)
    source
  end

  private

  attr_reader :account, :url

  def start(assistant, name_agent:)
    source = assistant.website_sources.create!(url: url)
    assistant.update!(config: assistant.config.merge('instant_agent' => { 'status' => 'running' }))
    Captain::Onboarding::InstantAgentJob.perform_later(source.id, name_agent: name_agent)
    Captain::Websites::DiscoverJob.perform_later(source.id)
    source
  end

  # The instant agent replaces the name and description once it has read the website.
  def create_assistant
    account.captain_assistants.create!(
      name: I18n.t('captain.guided_setup.default_agent_name'),
      description: I18n.t('captain.guided_setup.default_description', business: business_name)
    )
  end

  def business_name
    URI.parse(url).host.to_s.delete_prefix('www.').presence || account.name
  rescue URI::InvalidURIError
    account.name
  end

  def remember_website(source_url)
    return if account.custom_attributes['website'].present?

    account.custom_attributes['website'] = source_url
    account.save!
  end
end
