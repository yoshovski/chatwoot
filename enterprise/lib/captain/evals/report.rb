# Writes a finished run as a Markdown report for the PR or release and a JSON run record. The record's results use the
# shape services/ai/validation/captain_lab_bench.py reads, plus the checks of every repeat.
class Captain::Evals::Report
  def initialize(run, out_dir:)
    @run = run
    @out_dir = Pathname.new(out_dir)
  end

  def write
    FileUtils.mkdir_p(@out_dir)
    base = @out_dir.join("#{@run.suite.name}-#{@run.started_at.utc.strftime('%Y%m%dT%H%M%SZ')}")
    File.write("#{base}.md", markdown)
    File.write("#{base}.json", JSON.pretty_generate(record))
    ["#{base}.md", "#{base}.json"]
  end

  def header
    {
      suite: @run.suite.name, suite_sha256: @run.suite.sha256, revision: revision, started_at: @run.started_at.utc.iso8601,
      models: models, repeats: @run.repeat, llm_calls: @run.llm_calls, passed: @run.passed?
    }
  end

  def markdown
    lines = ["# Reply eval: #{@run.suite.name}", '', *header_lines, '', '| Id | Case | Passed | Failed checks |', '|---|---|---|---|']
    lines += @run.results.map { |result| table_row(result) }
    failures = @run.results.reject { |result| result[:passed] == @run.repeat }
    lines += failures.flat_map { |result| failure_section(result) }
    "#{lines.join("\n")}\n"
  end

  def record
    { **header, results: @run.results.map { |result| result_record(result) } }
  end

  private

  def header_lines
    [
      "- Suite: `#{@run.suite.name}` (sha256 `#{@run.suite.sha256[0, 12]}`)", "- Revision: `#{revision}`",
      "- Models: #{models.map { |stage, model| "#{stage} `#{model}`" }.join(', ')}",
      "- Repeats: #{@run.repeat}, LLM calls: #{@run.llm_calls}",
      "- Result: **#{@run.passed? ? 'PASS' : 'FAIL'}** (#{@run.results.count { |result| result[:passed] == @run.repeat }}/#{@run.results.size} cases)"
    ]
  end

  def table_row(result)
    failed = result[:repeats].flat_map { |item| item[:blocked] ? ['blocked'] : item[:checks].reject { |check| check[:pass] }.pluck(:name) }.uniq
    "| #{result[:case]['id']} | #{result[:case]['title']} | #{result[:passed]}/#{@run.repeat} | #{failed.join(', ')} |"
  end

  # The invented business makes the reply text safe to paste into a PR.
  def failure_section(result)
    item = result[:repeats].find { |repeat| !repeat[:pass] }
    bubbles = item[:messages].map { |message| "> #{message['content'].to_s.gsub("\n", "\n> ")}" }
    ['', "## #{result[:case]['id']}: #{result[:case]['title']} (repeat #{item[:repeat]})", '', "Customer: #{result[:case]['message']}",
     "Route: #{item.dig(:route, 'intent') || 'none'}", '', *failure_details(item), '', *bubbles.join("\n>\n> ---\n>\n").lines.map(&:chomp)]
  end

  def failure_details(item)
    return ["- blocked: #{item[:error]}"] if item[:blocked]

    item[:checks].reject { |check| check[:pass] }.map { |check| "- `#{check[:name]}`: #{check[:detail]}" }
  end

  def result_record(result)
    {
      id: result[:case]['id'], title: result[:case]['title'], passed: result[:passed], repeats: @run.repeat,
      status: result[:repeats].any? { |item| item[:blocked] } ? 'blocked' : 'completed',
      verdict: result[:passed] == @run.repeat ? 'pass' : 'fail', failure_stage: failure_stage(result),
      actual: actual(result[:repeats].find { |item| !item[:pass] } || result[:repeats].first),
      checks: result[:repeats].map { |item| item.slice(:repeat, :route, :llm_calls, :error, :checks) }
    }
  end

  def failure_stage(result)
    return if result[:passed] == @run.repeat

    result[:repeats].any? { |item| item[:blocked] } ? 'generation' : 'composition'
  end

  def actual(item)
    messages = item[:messages].to_a
    {
      messages: messages.pluck('content').compact, sources: item[:sources].to_a,
      buttons: messages.flat_map { |message| Array(message.dig('content_attributes', 'items')).pluck('title') }.compact,
      product_handles: [], labels: [], events: [], handoff: item[:handoff] == true
    }
  end

  def models
    {
      router: ENV.fetch('CAPTAIN_INTENT_ROUTER_MODEL', 'intent-router'),
      direct: ENV.fetch('CAPTAIN_KNOWLEDGE_ANSWER_MODEL', 'knowledge-answer'),
      action: ENV['CAPTAIN_ACTION_MODEL'].presence || InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_MODEL')&.value || 'default'
    }
  end

  # IMAGE_TAG when the run passes it (docker exec -e IMAGE_TAG=...), else the commit: GIT_HASH reads the image's
  # /app/.git_sha (production images have no .git) or git in a checkout.
  def revision
    @revision ||= ENV['IMAGE_TAG'].presence || (GIT_HASH == 'unknown' ? GIT_HASH : GIT_HASH[0, 12])
  end
end
