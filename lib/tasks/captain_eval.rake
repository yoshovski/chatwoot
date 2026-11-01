namespace :captain do
  desc 'Run a reply eval suite with the real models - SUITE=reply_basics REPEAT=3 ONLY=R01,R05 OUT=tmp/evals JUDGE=1 CONFIRM=1'
  task eval: :environment do
    suite = Captain::Evals::Suite.load(ENV.fetch('SUITE', 'reply_basics'))
    run = Captain::Evals::Run.new(
      suite: suite, repeat: Integer(ENV.fetch('REPEAT', '3')), only: ENV['ONLY']&.split(',')&.map(&:strip), judge: ENV['JUDGE'] == '1'
    )
    run.check_setup!
    puts "Suite #{suite.name}: about #{run.estimated_calls} LLM calls (#{run.repeat} repeats)."
    if run.estimated_calls > 100 && ENV['CONFIRM'] != '1'
      puts 'More than 100 LLM calls: set CONFIRM=1 to run.'
      exit 2
    end

    run.perform do |result|
      calls = result[:repeats].sum { |item| item[:llm_calls].to_i }
      puts "#{result[:case]['id']} #{result[:passed]}/#{run.repeat} (#{calls} LLM calls) #{result[:case]['title']}"
    end
    paths = Captain::Evals::Report.new(run, out_dir: ENV.fetch('OUT', Rails.root.join('tmp/evals').to_s)).write
    puts "#{run.passed? ? 'PASS' : 'FAIL'}: #{paths.join(' ')}"
    exit(run.passed? ? 0 : 1)
  rescue Captain::Evals::Suite::Invalid, Captain::Evals::Run::SetupError => e
    puts "Setup error: #{e.message}"
    exit 2
  end
end
