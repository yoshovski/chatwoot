# Maintains only the scenario explicitly owned by the guided lead settings.
class Captain::Leads::GuidedSetupService
  DEFAULT_TRIGGER = 'A business is interested in buying, pricing, a demo, an integration or a partnership. Excludes personal end-user support.'.freeze

  def initialize(assistant)
    @assistant = assistant
  end

  def perform
    scenario_id = @assistant.config['lead_scenario_id']
    scenario = @assistant.scenarios.find_by(id: scenario_id)
    unless @assistant.config['lead_guided_setup'] == true
      scenario&.update!(enabled: false)
      return
    end

    scenario ||= @assistant.scenarios.build(account: @assistant.account)
    pause_previous_capture_scenarios if scenario.new_record?
    update_scenario(scenario)
    @assistant.update!(config: @assistant.config.merge('lead_scenario_id' => scenario.id)) if scenario_id != scenario.id
  end

  private

  def update_scenario(scenario)
    scenario.update!(title: I18n.t('captain.leads.scenario_title'), description: @assistant.config['lead_trigger'].presence || DEFAULT_TRIGGER,
                     instruction: instructions, enabled: @assistant.leads_enabled?)
  end

  def instructions
    <<~TEXT.strip
      Help interested businesses understand the offering, then proactively start email follow-up when useful.
      Follow the shared business lead capture rules and configured fields and categories.
      Offer [@Request business follow-up](tool://request_lead_followup) once the need is clear. Known contact details are reused automatically; otherwise a form saves on submission. Do not ask a separate permission question.
      Use [@Save business lead](tool://save_lead_details) only for later captured-lead updates or agreed typed capture on channels without forms.
      Business-specific preferences:
      #{@assistant.config['lead_instructions'].presence || 'No additional preferences.'}
    TEXT
  end

  def pause_previous_capture_scenarios
    @assistant.scenarios.enabled.where('tools @> ?::jsonb', ['save_lead_details'].to_json).find_each do |scenario|
      scenario.update!(enabled: false)
    end
  end
end
