require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Captain::GuidedSetup', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:base_url) { "/api/v1/accounts/#{account.id}/captain/guided_setup" }
  let(:analyzer) { instance_double(Captain::Onboarding::WebsiteAnalyzerService) }

  def json_response = JSON.parse(response.body)

  before do
    allow(Captain::Onboarding::WebsiteAnalyzerService).to receive(:new).and_return(analyzer)
    allow(analyzer).to receive(:analyze).and_return(
      success: true, data: { business_name: 'Example', suggested_assistant_name: 'Example Helper', description: 'You help Example customers.' }
    )
  end

  it 'is for administrators only' do
    get base_url, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'returns an empty state for a new account' do
    get base_url, headers: admin.create_new_auth_token, as: :json

    expect(json_response).to eq('assistant_id' => nil, 'website_source' => nil, 'widget_inbox' => nil, 'agent_live' => false,
                                'readiness' => 'no_agent')
  end

  describe 'POST website' do
    it 'creates the AI agent from the website and starts discovery' do
      expect do
        post "#{base_url}/website", params: { url: 'www.example.com' }, headers: admin.create_new_auth_token, as: :json
      end.to have_enqueued_job(Captain::Websites::DiscoverJob)

      expect(response).to have_http_status(:accepted)
      assistant = account.captain_assistants.sole
      expect(assistant).to have_attributes(name: 'Example Helper', description: 'You help Example customers.')
      expect(json_response).to include('assistant_id' => assistant.id, 'readiness' => 'no_knowledge')
      expect(json_response['website_source']).to include('url' => 'https://www.example.com', 'status' => 'pending')
      expect(account.reload.custom_attributes['website']).to eq('https://www.example.com')
    end

    it 'names the agent after the host when the analyzer fails' do
      allow(analyzer).to receive(:analyze).and_return(success: false, data: {})

      post "#{base_url}/website", params: { url: 'https://shop.example.com' }, headers: admin.create_new_auth_token, as: :json

      expect(account.captain_assistants.sole).to have_attributes(name: 'AI agent', description: include('shop.example.com'))
    end

    it 'reuses the existing agent and website source' do
      assistant = create(:captain_assistant, account: account)
      source = Captain::WebsiteSource.create!(assistant: assistant, url: 'https://www.example.com')

      expect do
        post "#{base_url}/website", params: { url: 'https://www.example.com/' }, headers: admin.create_new_auth_token, as: :json
      end.not_to have_enqueued_job(Captain::Websites::DiscoverJob)

      expect(account.captain_assistants.count).to eq(1)
      expect(json_response['website_source']['id']).to eq(source.id)
      expect(analyzer).not_to have_received(:analyze)
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
  end
end
