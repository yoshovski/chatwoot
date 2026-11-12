require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Captain::GuidedSetup', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:base_url) { "/api/v1/accounts/#{account.id}/captain/guided_setup" }

  def json_response = JSON.parse(response.body)

  it 'is for administrators only' do
    get base_url, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'returns an empty state for a new account' do
    get base_url, headers: admin.create_new_auth_token, as: :json

    expect(json_response).to eq('assistant_id' => nil, 'website_source' => nil, 'widget_inbox' => nil, 'agent_live' => false,
                                'readiness' => 'no_agent', 'instant_agent' => nil, 'quick_ready' => false, 'learned' => 0, 'total' => 0)
  end

  describe 'POST website' do
    it 'creates the AI agent, starts the instant agent and starts discovery' do
      expect do
        post "#{base_url}/website", params: { url: 'www.example.com' }, headers: admin.create_new_auth_token, as: :json
      end.to have_enqueued_job(Captain::Websites::DiscoverJob)
        .and have_enqueued_job(Captain::Onboarding::InstantAgentJob).with(kind_of(Integer), name_agent: true)

      expect(response).to have_http_status(:accepted)
      assistant = account.captain_assistants.sole
      expect(assistant).to have_attributes(name: 'AI agent', description: include('example.com'))
      expect(json_response).to include('assistant_id' => assistant.id, 'readiness' => 'no_knowledge', 'quick_ready' => false,
                                       'instant_agent' => { 'status' => 'running' })
      expect(json_response['website_source']).to include('url' => 'https://www.example.com', 'status' => 'pending')
      expect(account.reload.custom_attributes['website']).to eq('https://www.example.com')
    end

    it 'keeps the name of an existing agent when it adds a website' do
      create(:captain_assistant, account: account)

      expect do
        post "#{base_url}/website", params: { url: 'https://www.example.com' }, headers: admin.create_new_auth_token, as: :json
      end.to have_enqueued_job(Captain::Onboarding::InstantAgentJob).with(kind_of(Integer), name_agent: false)
    end

    it 'shows what the instant agent learned' do
      assistant = create(:captain_assistant, account: account, config: { 'instant_agent' => { 'status' => 'ready', 'starter_questions' => ['Hi?'] } })
      source = Captain::WebsiteSource.create!(assistant: assistant, url: 'https://www.example.com')
      create(:captain_document, assistant: assistant, account: account, status: :available, external_link: 'https://www.example.com',
                                metadata: { 'website_source_id' => source.id, 'quick_start' => true })

      get base_url, headers: admin.create_new_auth_token, as: :json

      expect(json_response).to include('quick_ready' => true, 'learned' => 1, 'total' => 1, 'readiness' => 'ready',
                                       'instant_agent' => { 'status' => 'ready', 'starter_questions' => ['Hi?'] })
    end

    it 'reuses the existing agent and website source' do
      assistant = create(:captain_assistant, account: account)
      source = Captain::WebsiteSource.create!(assistant: assistant, url: 'https://www.example.com')

      expect do
        post "#{base_url}/website", params: { url: 'https://www.example.com/' }, headers: admin.create_new_auth_token, as: :json
      end.not_to have_enqueued_job(Captain::Websites::DiscoverJob)

      expect(account.captain_assistants.count).to eq(1)
      expect(json_response['website_source']['id']).to eq(source.id)
    end

    it 'rejects an address that is not a website' do
      post "#{base_url}/website", params: { url: 'not a website' }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['error']).to eq('Enter a website address like example.com.')
    end
  end

  describe 'POST go_live' do
    let(:assistant) { create(:captain_assistant, account: account) }

    it 'needs knowledge first' do
      assistant
      post "#{base_url}/go_live", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response).to include('readiness' => 'no_knowledge')
    end

    it 'creates the website chat inbox and connects the agent' do
      create(:captain_document, assistant: assistant, account: account, status: :available)
      account.update!(custom_attributes: { 'website' => 'https://www.example.com' })

      post "#{base_url}/go_live", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      inbox = account.inboxes.sole
      expect(inbox.channel).to have_attributes(website_url: 'https://www.example.com')
      expect(assistant.inboxes).to contain_exactly(inbox)
      expect(json_response).to include('agent_live' => true, 'readiness' => 'ready')
      expect(json_response['widget_inbox']['web_widget_script']).to include(inbox.channel.website_token)
    end

    it 'keeps an inbox another agent answers in' do
      create(:captain_document, assistant: assistant, account: account, status: :available)
      inbox = create(:channel_widget, account: account).inbox
      create(:captain_inbox, captain_assistant: create(:captain_assistant, account: account), inbox: inbox)

      post "#{base_url}/go_live", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['error']).to include('Another AI agent')
    end
  end

  describe 'POST check_installation' do
    let!(:channel) { create(:channel_widget, account: account, website_url: 'https://www.example.com') }
    let(:inbox) { channel.inbox }

    def check
      post "#{base_url}/check_installation", headers: admin.create_new_auth_token, as: :json
      json_response['status']
    end

    it 'is installed once the widget reported a visit' do
      create(:contact_inbox, inbox: inbox, website_activity: { 'page_url' => 'https://www.example.com/' })

      expect(check).to eq('installed')
    end

    it 'finds the script on the page before the first visit' do
      stub_request(:get, 'https://www.example.com').to_return(body: "<script>websiteToken: '#{channel.website_token}'</script>")

      expect(check).to eq('script_found')
    end

    it 'says when the script is missing or the site cannot be read' do
      stub_request(:get, 'https://www.example.com').to_return(body: '<html></html>')
      expect(check).to eq('not_found')

      stub_request(:get, 'https://www.example.com').to_return(status: 500)
      expect(check).to eq('unreachable')
    end

    it 'checks the website inbox it is given' do
      other_channel = create(:channel_widget, account: account, website_url: 'https://www.example.com')
      stub_request(:get, 'https://www.example.com').to_return(body: "<script>websiteToken: '#{other_channel.website_token}'</script>")

      post "#{base_url}/check_installation", params: { inbox_id: other_channel.inbox.id }, headers: admin.create_new_auth_token, as: :json

      expect(json_response['status']).to eq('script_found')
    end

    it 'does not check an inbox of another account or one that is not a website' do
      post "#{base_url}/check_installation", params: { inbox_id: create(:channel_widget).inbox.id },
                                             headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:not_found)

      post "#{base_url}/check_installation", params: { inbox_id: create(:inbox, :with_email, account: account).id },
                                             headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end
end
