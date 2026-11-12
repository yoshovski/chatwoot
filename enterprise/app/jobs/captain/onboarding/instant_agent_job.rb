# Gives a new AI agent its first knowledge while the full website import runs: the pages the instant agent read are
# stored as "quick start" documents of the website source, and the agent the guided setup just created gets its name
# and brief. The full import replaces these documents (Captain::Onboarding::QuickStartPages).
class Captain::Onboarding::InstantAgentJob < ApplicationJob
  queue_as :high
  discard_on ActiveRecord::RecordNotFound

  def perform(source_id, name_agent: false)
    source = Captain::WebsiteSource.find(source_id)
    assistant = source.assistant
    result = Captain::Onboarding::InstantAgentService.new(source.url, account_id: source.account_id).perform

    identity = { name: result[:profile][:name], description: result[:profile][:brief] }.compact_blank
    assistant.update!(identity) if name_agent && identity.any?
    stored = result[:pages].count { |page| store(source, page) }
    finish(assistant, result, stored)
  rescue StandardError
    assistant&.reload&.update!(config: assistant.config.merge('instant_agent' => { 'status' => 'blocked' }))
    raise
  end

  private

  def store(source, page)
    return false if source.assistant.documents.exists?(external_link: page[:url].delete_suffix('/'))

    source.assistant.documents.create!(external_link: page[:url], name: page[:title], content: page[:content], status: :available,
                                       metadata: { 'website_source_id' => source.id, 'quick_start' => true })
  rescue Captain::Document::LimitExceededError
    false
  end

  # A site that blocks fetching is not an error: the setup asks the owner to add their content instead.
  def finish(assistant, result, stored)
    profile = result[:profile]
    state = { 'status' => stored.positive? ? 'ready' : 'blocked', 'language' => profile[:language], 'brand_color' => profile[:brand_color],
              'logo_url' => profile[:logo_url], 'starter_questions' => profile[:starter_questions], 'finished_at' => Time.current.iso8601 }
    assistant.reload.update!(config: assistant.config.merge('instant_agent' => state.compact))
  end
end
