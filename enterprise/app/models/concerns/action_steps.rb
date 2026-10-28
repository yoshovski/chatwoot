# The steps of a custom tool ("action" in the UI): up to three requests and two verify checks that run in order,
# plus the response fields saved as outputs. The first request step is mirrored into the legacy endpoint columns
# for one release. Captain::ActionStepsValidator checks the shapes and the template references.
module Concerns::ActionSteps
  extend ActiveSupport::Concern

  LEGACY_STEP_KEY = 'request'.freeze

  included do
    before_validation :normalize_action_fields
    before_validation :sync_legacy_request_columns
    before_validation :default_execution_mode, on: :create
    validates_with Captain::ActionStepsValidator
  end

  def request_steps = steps.select { |step| step['type'] == 'request' }

  def all_requests_read_only? = request_steps.all? { |step| step['method'] == 'GET' }

  def read_only_action? = all_requests_read_only? && execution_mode == 'background'

  def outputs_for_step(step_key) = outputs.select { |output| output['step'] == step_key }

  # The customer-facing message of a check step that stopped the run, if it has one.
  def failure_message_for(step_key)
    steps.find { |step| step['key'] == step_key && step['type'] == 'verify' }&.dig('failure_message').presence
  end

  # Legacy templates were never checked against the params, so a step built from them isn't either.
  def action_templates_changed?
    return false if @steps_from_legacy_columns

    will_save_change_to_steps? || will_save_change_to_outputs? || will_save_change_to_messages? || will_save_change_to_param_schema?
  end

  private

  def normalize_action_fields
    self.steps = Array(steps).as_json
    self.outputs = Array(outputs).as_json
    self.messages = (messages || {}).as_json
  end

  # Steps win when they changed; a write to the legacy columns alone (older clients, rollback) updates the first
  # request step instead.
  def sync_legacy_request_columns
    @steps_from_legacy_columns = false
    if steps.blank?
      @steps_from_legacy_columns = endpoint_url.present?
      self.steps = [legacy_request_step] if endpoint_url.present?
    elsif will_save_change_to_steps?
      write_legacy_columns(request_steps.first)
    elsif will_save_change_to_endpoint_url? || will_save_change_to_http_method? || will_save_change_to_request_template?
      @steps_from_legacy_columns = true
      replace_first_request_step(legacy_request_step)
    end
  end

  def legacy_request_step
    existing = request_steps.first || {}
    existing.merge('key' => existing['key'] || LEGACY_STEP_KEY, 'type' => 'request', 'method' => http_method,
                   'url' => endpoint_url, 'headers' => existing['headers'] || [], 'body_type' => existing['body_type'] || 'json',
                   'body' => request_template.to_s)
  end

  def replace_first_request_step(step)
    index = steps.index { |item| item['type'] == 'request' }
    self.steps = index ? steps.dup.tap { |list| list[index] = step } : steps + [step]
  end

  # The legacy column only knows GET and POST; other methods roll back as POST.
  def write_legacy_columns(step)
    return if step.blank?

    self.endpoint_url = step['url']
    self.http_method = step['method'] == 'GET' ? 'GET' : 'POST'
    self.request_template = step['body'].presence
  end

  def default_execution_mode
    return if execution_mode_came_from_user?

    self.execution_mode = all_requests_read_only? ? 'background' : 'confirm'
  end
end
