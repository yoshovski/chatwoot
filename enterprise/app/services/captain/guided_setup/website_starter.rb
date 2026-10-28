# Starts the knowledge import from the account's website. Creates the AI agent first when there is none, named from
# the website analyzer, and remembers the URL as the account website (the chat widget inbox is created from it).
class Captain::GuidedSetup::WebsiteStarter
  def initialize(account, url)
    @account = account
    value = url.to_s.strip
    @url = value.match?(%r{\Ahttps?://}i) || value.blank? ? value : "https://#{value}"
  end

  def perform
    assistant = Captain::GuidedSetup::State.new(account).assistant || create_assistant
    source = assistant.website_sources.find_by(url: Captain::Websites::UrlPolicy.normalize(url)) || start_discovery(assistant)
    remember_website(source.url)
    source
  end

  private

  attr_reader :account, :url

  def start_discovery(assistant)
    source = assistant.website_sources.create!(url: url)
    Captain::Websites::DiscoverJob.perform_later(source.id)
    source
  end

  def create_assistant
    info = analyzed_info
    account.captain_assistants.create!(
      name: info[:suggested_assistant_name].presence || I18n.t('captain.guided_setup.default_agent_name'),
      description: info[:description].presence || I18n.t('captain.guided_setup.default_description', business: business_name(info))
    )
  end

  # The analyzer reads one page with an LLM; a failure only costs the nicer name, so it never stops the import.
  def analyzed_info
    result = Captain::Onboarding::WebsiteAnalyzerService.new(url).analyze
    result[:success] ? result[:data] : {}
  rescue StandardError => e
    Rails.logger.warn "[Captain GuidedSetup] Website analysis skipped: #{e.message}"
    {}
  end

  def business_name(info)
    info[:business_name].presence || URI.parse(url).host.to_s.delete_prefix('www.').presence || account.name
  rescue URI::InvalidURIError
    account.name
  end

  def remember_website(source_url)
    return if account.custom_attributes['website'].present?

    account.custom_attributes['website'] = source_url
    account.save!
  end
end
