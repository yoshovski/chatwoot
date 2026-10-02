# Run with rails runner in a disposable lab process using the new proxy files.
# Records are synthetic and rolled back. No mail or public messages are sent.
raise 'Lab validation must be explicitly enabled' unless ENV['CWAI_VALIDATION_ALLOW'] == 'true'

class LabKnowledgeValidation
  def initialize(session)
    @session = session
  end

  def request(method, path, user, status, payload = nil)
    headers = user ? user.create_new_auth_token : {}
    @session.public_send(method, path, headers: headers, params: payload, as: :json)
    raise "Expected #{status}, got #{@session.response.status} for #{method} #{path}" unless @session.response.status == status

    @session.response.parsed_body unless status == 204
  end
end

def lab_users(account_id)
  Array.new(3) do |i|
    User.create!(name: 'Lab editor', email: "cwai-#{account_id}-#{i}@example.test",
                 password: "Lab!9#{SecureRandom.hex(24)}", confirmed_at: Time.current)
  end
end

ActiveRecord::Base.transaction do
  ids = %w[CWAI_VALIDATION_ACCOUNT_A CWAI_VALIDATION_ACCOUNT_B].map { |key| Integer(ENV.fetch(key)) }
  accounts = ids.map { |id| Account.create!(id: id, name: 'Synthetic CWAI validation', locale: 'en') }
  accounts.each { |account| account.enable_features!('native_ai_knowledge') }
  users = lab_users(ids.first)
  AccountUser.create!(account: accounts.first, user: users[0], role: :administrator)
  AccountUser.create!(account: accounts.first, user: users[1], role: :agent)
  AccountUser.create!(account: accounts.last, user: users[2], role: :administrator)
  session = ActionDispatch::Integration::Session.new(Rails.application)
  session.host!('localhost')
  validator = LabKnowledgeValidation.new(session)
  prefix = "/api/v1/accounts/#{accounts.first.id}/ai_agents/knowledge"
  validator.request(:get, "#{prefix}/bases", nil, 401)
  bases = validator.request(:get, "#{prefix}/bases", users[0], 200)
  raise 'No service-side validation base' if bases.empty?

  validator.request(:get, "#{prefix}/bases", users[1], 200)
  validator.request(:get, "#{prefix}/bases", users[2], 401)
  validator.request(:post, "#{prefix}/bases", users[1], 401, { name: 'Forbidden' })
  validator.request(:post, "#{prefix}/bases", users[0], 422, { name: 'Forged', credential_ref: 'other' })
  validator.request(:get, "#{prefix}/bases/invalid", users[0], 422)
  base = validator.request(:post, "#{prefix}/bases", users[0], 201, { name: 'Rails proxy synthetic base' })
  answer = "  Verbatim from Rails\nΩ  "
  entry = validator.request(:post, "#{prefix}/bases/#{base['id']}/entries", users[0], 201, { question: 'Question?', answer: answer })
  raise 'Rails changed canonical text' unless entry.dig('revision', 'answer') == answer

  validator.request(:patch, "#{prefix}/entries/#{entry['id']}/state", users[0], 200, { enabled: false })
  bot = AgentBot.create!(account: accounts.last, name: 'Other account bot', outgoing_url: 'https://example.test')
  validator.request(:post, "#{prefix}/agents", users[0], 404, { chatwoot_agent_bot_id: bot.id })
  accounts.first.disable_features!('native_ai_knowledge')
  validator.request(:get, "#{prefix}/bases", users[0], 401)
  puts 'PASS: Rails membership, role, feature flag, bot ownership, parameter rejection and signed service proxy'
  raise ActiveRecord::Rollback
end
