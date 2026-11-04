# Runs every selected case of a suite REPEAT times and checks each reply. A case passes only when every repeat passes.
class Captain::Evals::Run
  # Router, direct answer or action agent, and sometimes a retry or a tool turn.
  ESTIMATED_CALLS_PER_REPEAT = 3
  JUDGE_PROMPT = 'You grade one customer-support reply against a rubric. Answer with exactly PASS or FAIL.'.freeze

  class SetupError < StandardError; end

  attr_reader :suite, :repeat, :results, :llm_calls, :started_at

  def initialize(suite:, repeat:, only: nil, judge: false)
    @suite = suite
    @repeat = repeat
    @cases = suite.cases(only: only)
    @judge = judge
    @results = []
    @llm_calls = 0
  end

  def self.estimated_calls(case_count, repeat) = case_count * repeat * ESTIMATED_CALLS_PER_REPEAT

  def estimated_calls = self.class.estimated_calls(@cases.size, repeat)

  def check_setup!
    raise SetupError, 'No cases selected' if @cases.empty?
    raise SetupError, 'CAPTAIN_OPEN_AI_API_KEY is not configured' if InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value.blank?
  end

  def perform(&progress)
    check_setup!
    @started_at = Time.current
    @results = @cases.map do |test_case|
      repeats = Array.new(repeat) { |index| run_repeat(test_case, index) }
      @llm_calls += repeats.sum { |item| item[:llm_calls].to_i }
      result = { case: test_case, repeats: repeats, passed: repeats.count { |item| item[:pass] } }
      progress&.call(result)
      result
    end
    self
  end

  def passed? = results.all? { |result| result[:passed] == repeat }

  private

  def run_repeat(test_case, index)
    observation = Captain::Evals::CaseRunner.new(suite: suite, test_case: test_case).run
    return blocked(observation[:error], observation).merge(repeat: index + 1) if observation[:error]

    observation[:judgements] = judgements(test_case, observation) if @judge
    checks = suite.checks_for(test_case).map { |check| Captain::Evals::Checks.run(check, observation) }
    observation.merge(repeat: index + 1, checks: checks, pass: checks.all? { |check| check[:pass] })
  rescue StandardError => e
    blocked("#{e.class.name}: #{e.message}", { messages: [] }).merge(repeat: index + 1)
  end

  def blocked(error, observation)
    observation.merge(error: error, checks: [], pass: false, blocked: true)
  end

  def judgements(test_case, observation)
    reply = Captain::Evals::Checks.full_text(observation)
    rubrics = suite.checks_for(test_case).filter_map { |check| check['judge'] if check.is_a?(Hash) }
    rubrics.index_with do |rubric|
      chat = Captain::Assistant::TieredLlmClient.chat(
        account_id: nil, model: ENV.fetch('CAPTAIN_EVAL_JUDGE_MODEL', ENV.fetch('CAPTAIN_INTENT_ROUTER_MODEL', 'intent-router')), timeout: 30
      ).with_instructions(JUDGE_PROMPT)
      @llm_calls += 1
      verdict = chat.ask("Rubric: #{rubric}\nCustomer: #{test_case['message']}\nReply:\n#{reply}").content.to_s
      verdict.strip.upcase.start_with?('PASS') ? 'PASS' : 'FAIL'
    end
  end
end
