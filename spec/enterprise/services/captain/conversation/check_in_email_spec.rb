require 'rails_helper'

# Visitors who left get check-ins and lead offers through the inbox's existing email continuity; no new mailer.
RSpec.describe 'Captain check-ins by email' do # rubocop:disable RSpec/DescribeClass
  let(:account) { create(:account) }
  let(:continuity) { true }
  let(:inbox) { create(:inbox, account: account, channel: create(:channel_widget, account: account, continuity_via_email: continuity)) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:contact) { create(:contact, account: account, email: 'visitor@example.com') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, status: :pending) }

  before do
    allow(Redis::Alfred).to receive(:set).and_return(true)
    ActiveJob::Base.queue_adapter = :test
  end

  %w[check_in lead_offer].each do |kind|
    context "with a #{kind}" do
      let(:message) do
        create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :outgoing, sender: assistant,
                         content: 'Is there anything else I can help you with?',
                         additional_attributes: { 'captain_initiated' => kind })
      end

      it 'is email notifiable and is emailed with continuity on' do
        expect(message.email_notifiable_message?).to be(true)
        expect { Messages::SendEmailNotificationService.new(message: message).perform }
          .to have_enqueued_job(ConversationReplyEmailJob).with(conversation.id, message.id)
      end

      context 'with continuity off' do
        let(:continuity) { false }

        it 'sends nothing' do
          expect { Messages::SendEmailNotificationService.new(message: message).perform }
            .not_to have_enqueued_job(ConversationReplyEmailJob)
        end
      end
    end
  end
end
