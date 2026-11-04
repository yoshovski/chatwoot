require 'rails_helper'

RSpec.describe Captain::Evals::Report do
  let(:suite) { Captain::Evals::Suite.load('reply_basics') }
  let(:out_dir) { Rails.root.join('tmp/evals-spec') }
  let(:case_runner) { instance_double(Captain::Evals::CaseRunner) }
  let(:welcome) { 'Hello and welcome to Acme!' }
  let(:observation) do
    { messages: [{ 'content' => "#{welcome}\n\n#{welcome} Open the three-dot menu.", 'content_type' => 'text' }],
      route: { 'intent' => 'faq_kb', 'reason' => 'classified' }, llm_calls: 2, handoff: false, sources: [], fixture_urls: [], link_allowlist: ['*'] }
  end

  before do
    create(:installation_config, name: 'CAPTAIN_OPEN_AI_API_KEY', value: 'test-key')
    allow(Captain::Evals::CaseRunner).to receive(:new).and_return(case_runner)
    allow(case_runner).to receive(:run) { observation.deep_dup }
  end

  after { FileUtils.rm_rf(out_dir) }

  it 'writes a failing Markdown report and a bench-shaped JSON record' do
    run = Captain::Evals::Run.new(suite: suite, repeat: 2, only: %w[R01 R04]).perform
    markdown_path, json_path = described_class.new(run, out_dir: out_dir).write
    record = JSON.parse(File.read(json_path))

    expect(run.passed?).to be(false)
    expect(run.llm_calls).to eq(8)
    expect(File.read(markdown_path)).to include('**FAIL**', '| R01 | First reply, how-to with video (CWAI-141) | 0/2 |',
                                                'repeated: hello and welcome to acme', "> #{welcome}")
    expect(record).to include('suite' => 'reply_basics', 'suite_sha256' => suite.sha256, 'repeats' => 2, 'passed' => false)
    expect(record['results'].first).to include('id' => 'R01', 'status' => 'completed', 'verdict' => 'fail', 'failure_stage' => 'composition')
    expect(record['results'].first['actual']).to include('handoff' => false, 'messages' => [observation[:messages].first['content']])
    expect(record['results'].first['checks'].size).to eq(2)
  end

  it 'marks a case blocked when the runner fails' do
    allow(case_runner).to receive(:run).and_raise(StandardError, 'LiteLLM unreachable')

    run = Captain::Evals::Run.new(suite: suite, repeat: 1, only: ['R01']).perform

    expect(described_class.new(run, out_dir: out_dir).record[:results].first).to include(status: 'blocked', failure_stage: 'generation')
  end

  it 'records why a repeat was blocked when the runner returned an error' do
    allow(case_runner).to receive(:run) { observation.merge(messages: [], error: 'faraday_timeout_error: execution expired') }

    run = Captain::Evals::Run.new(suite: suite, repeat: 1, only: ['R01']).perform
    report = described_class.new(run, out_dir: out_dir)

    expect(report.record[:results].first[:checks].first).to include(repeat: 1, error: 'faraday_timeout_error: execution expired')
    expect(report.markdown).to include('- blocked: faraday_timeout_error: execution expired')
  end

  it 'names the action model and the reply schema the case runner resolved' do
    allow(case_runner).to receive(:run) { observation.merge(schema_v2: true, action_model: 'gpt-6-luna') }

    report = described_class.new(Captain::Evals::Run.new(suite: suite, repeat: 1, only: ['R01']).perform, out_dir: out_dir)

    expect(report.header).to include(schema_v2: true)
    expect(report.header[:models]).to include(action: 'gpt-6-luna')
    expect(report.markdown).to include('action `gpt-6-luna`', '- Reply schema v2: on')
  end

  it 'raises a setup error without the Captain API key' do
    InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY').destroy!

    expect { Captain::Evals::Run.new(suite: suite, repeat: 1).perform }.to raise_error(Captain::Evals::Run::SetupError)
  end

  describe 'revision' do
    let(:run) { Captain::Evals::Run.new(suite: suite, repeat: 1, only: ['R01']).perform }

    it 'names the IMAGE_TAG when the run passes one' do
      with_modified_env(IMAGE_TAG: 'v4.18.0-internal-v6.0.12') do
        expect(described_class.new(run, out_dir: out_dir).header[:revision]).to eq('v4.18.0-internal-v6.0.12')
      end
    end

    # Production images have no .git; GIT_HASH reads their /app/.git_sha.
    it 'names the commit without one' do
      stub_const('GIT_HASH', '3eee45283081a95732d1b23cd5942647b4abbfac')

      expect(described_class.new(run, out_dir: out_dir).markdown).to include('- Revision: `3eee45283081`')
    end
  end

  it 'estimates the calls of a full run' do
    expect(Captain::Evals::Run.new(suite: suite, repeat: 3).estimated_calls).to eq(126)
  end
end
