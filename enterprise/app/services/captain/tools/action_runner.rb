# Runs a custom tool's steps in order, for the AI and for the test panel. Each request goes through SafeFetch and
# saves its outputs; a verify step compares two values in Ruby. The first failing step stops the run, so later steps
# (and the AI) never see data from a failed check.
class Captain::Tools::ActionRunner
  # 1MB of text ≈ 250K tokens, which exceeds most LLM context windows.
  MAX_RESPONSE_SIZE = 1.megabyte
  TIME_BUDGET = 20.0
  CONTACT_FIELDS = Captain::ActionStepsValidator::CONTACT_FIELDS
  PHONE_DIGITS_COMPARED = 9
  PHONE_DIGITS = ->(value) { value.gsub(/\D/, '').last(PHONE_DIGITS_COMPARED) }
  COMPARATORS = {
    'exact' => ->(left, right) { left == right },
    'case_insensitive' => ->(left, right) { left.casecmp?(right) },
    'email' => ->(left, right) { left.downcase == right.downcase },
    'phone' => ->(left, right) { PHONE_DIGITS.call(left).present? && PHONE_DIGITS.call(left) == PHONE_DIGITS.call(right) }
  }.freeze

  Result = Data.define(:ok, :failed_step, :outputs, :step_results, :error_kind, :status) do
    def ok? = ok

    def last_request_body = step_results.reverse.find { |step| step[:type] == 'request' }&.dig(:body)
  end

  # state: the tool context state, for the X-Chatwoot-* metadata headers. mode: :live traces each step; :test
  # (the action page) also returns the values a verify step compared.
  def initialize(custom_tool, state: {}, mode: :live)
    @tool = custom_tool
    @state = state || {}
    @mode = mode
  end

  # contact: email, phone_number, name and verified (the contact inbox is HMAC-verified).
  # outputs/start_at let a later run continue after steps that already ran; stop_after ends the run after that step.
  def run(params:, contact:, outputs: {}, start_at: 0, stop_after: nil)
    @params = @tool.param_schema.to_h { |param| [param['name'], nil] }.merge(params.to_h.stringify_keys)
    @contact = contact.to_h.stringify_keys
    @outputs = outputs.to_h.stringify_keys
    @deadline = monotonic_now + TIME_BUDGET
    @results = []

    selected_steps(start_at, stop_after).each do |step|
      failure = run_step(step)
      return result(failure.merge(failed_step: step['key'])) if failure
    end
    result({})
  end

  private

  def selected_steps(start_at, stop_after)
    steps = @tool.steps.drop(start_at)
    last = stop_after && steps.index { |step| step['key'] == stop_after }
    last ? steps.first(last + 1) : steps
  end

  def result(failure)
    Result.new(ok: failure.empty?, failed_step: failure[:failed_step], outputs: @outputs, step_results: @results,
               error_kind: failure[:error_kind], status: failure[:status])
  end

  def run_step(step)
    return { error_kind: :timeout } if remaining_time <= 0

    traced(step) do
      started = monotonic_now
      failure = step['type'] == 'verify' ? run_verify(step) : run_request(step)
      @results.last[:duration_ms] = ((monotonic_now - started) * 1000).round
      failure
    end
  end

  def run_request(step)
    record = { key: step['key'], type: 'request', ok: false }
    @results << record
    url, body, headers = build_request(step)
    record[:request] = { method: step['method'], url: url, headers: redacted(headers) }

    record[:status], record[:body] = fetch(step['method'], url, body, headers)
    record[:ok] = true
    extract_outputs(step, record)
  rescue SafeFetch::HttpError => e
    record[:status] = e.message.to_i
    record[:error] = e.message
    { error_kind: :http_error, status: record[:status] }
  rescue StandardError => e
    record[:error] = e.message
    { error_kind: :request_failed }
  end

  def fetch(method, url, body, headers)
    status = nil
    response_body = +''
    SafeFetch.fetch(
      url,
      method: method.downcase.to_sym,
      body: body,
      headers: headers,
      sensitive_headers: auth_headers.keys,
      http_basic_authentication: @tool.build_basic_auth_credentials,
      max_bytes: MAX_RESPONSE_SIZE,
      open_timeout: [remaining_time, SafeFetch::DEFAULT_OPEN_TIMEOUT].min,
      read_timeout: [remaining_time, SafeFetch::DEFAULT_READ_TIMEOUT].min,
      validate_content_type: false
    ) do |fetched|
      status = fetched.status
      response_body = fetched.tempfile.read
    end
    [status, response_body]
  end

  def build_request(step)
    body = render(step['body'].to_s).presence if step['method'] != 'GET'
    [render(step['url']), body, request_headers(step, body)]
  end

  def request_headers(step, body)
    headers = @tool.build_metadata_headers(@state)
    Array(step['headers']).each { |header| headers[header['name']] = render(header['value'].to_s) }
    headers['Content-Type'] ||= step['body_type'] == 'text' ? 'text/plain' : 'application/json' if body.present?
    headers.merge(auth_headers)
  end

  def auth_headers
    @auth_headers ||= @tool.build_auth_headers
  end

  def redacted(headers)
    headers.to_h { |name, value| [name, auth_headers.key?(name) ? '[REDACTED]' : value] }
  end

  def extract_outputs(step, record)
    data = parse_body(record[:body])
    missing = @tool.outputs_for_step(step['key']).select do |output|
      value = Captain::Tools::ResponsePath.dig(data, output['path'])
      @outputs[output['key']] = value
      output['required'] && (value.nil? || value == [])
    end
    record[:outputs] = @tool.outputs_for_step(step['key']).to_h { |output| [output['key'], @outputs[output['key']]] }
    return if missing.empty?

    record[:ok] = false
    record[:missing_outputs] = missing.pluck('key')
    { error_kind: :not_found }
  end

  def run_verify(step)
    left = render(step['left'].to_s).strip
    right = render(step['right'].to_s).strip
    ok = values_match?(step['compare'], left, right) && (!step['require_verified_contact'] || @contact['verified'] == true)
    record = { key: step['key'], type: 'verify', ok: ok }
    record[:compared] = { left: left, right: right } if @mode == :test
    @results << record
    ok ? nil : { error_kind: :verification_failed }
  rescue StandardError => e
    @results << { key: step['key'], type: 'verify', ok: false, error: e.message }
    { error_kind: :verification_failed }
  end

  # Never a match on blank values, so a missing field can't pass the check.
  def values_match?(compare, left, right)
    return false if left.blank? || right.blank?

    COMPARATORS.fetch(compare).call(left, right)
  end

  def render(template)
    return template if template.exclude?('{{') && template.exclude?('{%')

    @tool.send(:render_template, template, @params.merge('outputs' => @outputs, 'contact' => @contact.slice(*CONTACT_FIELDS)))
  end

  def parse_body(body)
    JSON.parse(body.to_s)
  rescue JSON::ParserError
    body
  end

  # One span per step with its status and outputs; never auth values or full bodies.
  def traced(step)
    return yield unless @mode == :live && ChatwootApp.otel_enabled?

    OpentelemetryConfig.tracer.in_span("captain.action.#{step['key']}") do |span|
      failure = yield
      record = @results.last
      span.set_attribute('langfuse.observation.type', 'span')
      span.set_attribute('langfuse.observation.output', record.slice(:type, :ok, :status, :duration_ms, :outputs).to_json)
      span.status = OpenTelemetry::Trace::Status.error('Step failed') unless record[:ok]
      failure
    end
  end

  def remaining_time = @deadline - monotonic_now

  def monotonic_now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
end
