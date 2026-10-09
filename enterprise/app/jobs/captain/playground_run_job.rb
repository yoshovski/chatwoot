# Runs one Captain V2 playground message outside the web request: a run with several tool calls often takes longer
# than the 15-second request timeout. The playground polls the result, which Redis keeps for a few minutes.
class Captain::PlaygroundRunJob < ApplicationJob
  queue_as :critical

  RESULT_TTL = 10.minutes

  def self.result(assistant, run_id)
    raw = Redis::Alfred.get(result_key(assistant, run_id))
    raw && JSON.parse(raw)
  end

  def self.result_key(assistant, run_id) = "captain:playground_run:#{assistant.id}:#{run_id}"

  def perform(assistant, run_id, configuration_params, message_history)
    store(assistant, run_id, status: 'done', response: generate_response(assistant, configuration_params, message_history))
  rescue StandardError => e
    # Retrying would repeat the model calls for a run the user already sees as failed.
    Rails.logger.error("Captain playground run #{run_id} failed: #{e.class}: #{e.message}")
    store(assistant, run_id, status: 'failed', error: e.message)
  end

  private

  def generate_response(assistant, configuration_params, message_history)
    if configuration_params
      return Captain::Playground::Runner.new(
        assistant: assistant, configuration_params: configuration_params, message_history: message_history
      ).generate_response
    end

    run_options = Captain::Assistant::AgentRunnerService::RunOptions.new(source: 'playground')
    runner = Captain::Assistant::AgentRunnerService.new(assistant: assistant, run_options: run_options)
    response = runner.generate_response(message_history: message_history)
    return response if response['error']

    response.merge(
      Captain::Playground::CustomerView.new(
        assistant: assistant, response: response, run_result: runner.last_run_result, message_history: message_history
      ).to_h
    )
  end

  def store(assistant, run_id, result)
    Redis::Alfred.setex(self.class.result_key(assistant, run_id), result.to_json, RESULT_TTL)
  end
end
