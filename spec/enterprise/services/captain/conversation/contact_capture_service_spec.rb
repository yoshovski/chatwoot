require 'rails_helper'

RSpec.describe Captain::Conversation::ContactCaptureService, type: :service do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Visitor 1', email: nil) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:service) { described_class.new(conversation: conversation, assistant: assistant) }

  before do
    allow(inbox).to receive(:captain_assistant).and_return(assistant)
    allow(Redis::Alfred).to receive(:set).and_return('OK')
  end

  describe '.extract_email' do
    it 'extracts and normalizes a valid email from text' do
      expect(described_class.extract_email('Hello, my email is User@Example.COM please contact me')).to eq('user@example.com')
    end

    it 'returns nil for text without valid email' do
      expect(described_class.extract_email('Hello world no email here')).to be_nil
      expect(described_class.extract_email(nil)).to be_nil
    end
  end

  describe '.missing_name?' do
    it 'returns true for blank or short names' do
      expect(described_class.missing_name?(nil)).to be true
      expect(described_class.missing_name?(build(:contact, name: ''))).to be true
      expect(described_class.missing_name?(build(:contact, name: 'A'))).to be true
    end

    it 'returns true for placeholder names' do
      %w[visitor Guest ANONYMOUS unknown Contact Customer].each do |placeholder|
        expect(described_class.missing_name?(build(:contact, name: placeholder))).to be true
      end
      expect(described_class.missing_name?(build(:contact, name: 'Guest 42'))).to be true
      expect(described_class.missing_name?(build(:contact, name: 'Customer #12'))).to be true
    end

    it 'returns true for Haikunator generated names' do
      expect(described_class.missing_name?(build(:contact, name: 'damp-water-56'))).to be true
      expect(described_class.missing_name?(build(:contact, name: 'autumn-resonance-422'))).to be true
    end

    it 'returns false for legitimate customer names' do
      expect(described_class.missing_name?(build(:contact, name: 'Stefan Yoshovski'))).to be false
      expect(described_class.missing_name?(build(:contact, name: 'Jane'))).to be false
      expect(described_class.missing_name?(build(:contact, name: 'Bo'))).to be false
    end
  end

  describe '.missing_email?' do
    it 'returns true when contact has no email' do
      expect(described_class.missing_email?(build(:contact, email: nil))).to be true
      expect(described_class.missing_email?(build(:contact, email: ''))).to be true
    end

    it 'returns false when contact has an email' do
      expect(described_class.missing_email?(build(:contact, email: 'test@example.com'))).to be false
    end

    it 'returns false when an email is present in the triggering message' do
      message = build(:message, content: 'Can I talk to someone? email: typed@example.com')
      expect(described_class.missing_email?(build(:contact, email: nil), triggering_message: message)).to be false
    end
  end

  describe '#capture_typed_email!' do
    let(:incoming_message) do
      create(
        :message,
        conversation: conversation,
        account: account,
        inbox: inbox,
        sender: contact,
        message_type: :incoming,
        content: 'My email is typed@example.com'
      )
    end

    it 'saves the typed email to the contact' do
      expect { service.capture_typed_email!(incoming_message) }
        .to change { contact.reload.email }.from(nil).to('typed@example.com')
    end

    it 'does not save or merge if the email already belongs to another contact in the account' do
      create(:contact, account: account, email: 'typed@example.com')

      expect { service.capture_typed_email!(incoming_message) }
        .not_to(change { contact.reload.email })
    end

    it 'ignores outgoing messages' do
      outgoing = create(:message, conversation: conversation, account: account, inbox: inbox,
                                  message_type: :outgoing, content: 'Email is typed@example.com')
      expect { service.capture_typed_email!(outgoing) }
        .not_to(change { contact.reload.email })
    end
  end

  describe '#post_form_if_needed!' do
    context 'when both name and email are missing' do
      it 'posts a form with both Name and Email fields' do
        expect(Redis::Alfred).to receive(:set)
          .with("captain:contact_form:#{conversation.id}:email_name", 1, nx: true, ex: 7.days.to_i)
          .and_return('OK')

        form_message = nil
        expect do
          form_message = service.post_form_if_needed!
        end.to change(conversation.messages, :count).by(1)

        expect(form_message.content_type).to eq('form')
        expect(form_message.content).to eq(described_class::FORM_TEXT)
        items = form_message.content_attributes['items']
        expect(items.map { |i| i['name'] }).to contain_exactly('name', 'email')
        expect(form_message.preserve_waiting_since).to be(true)
      end
    end

    context 'when only name is missing' do
      before { contact.update!(email: 'existing@example.com') }

      it 'posts a form with only the Name field' do
        expect(Redis::Alfred).to receive(:set)
          .with("captain:contact_form:#{conversation.id}:name", 1, nx: true, ex: 7.days.to_i)
          .and_return('OK')

        form_message = service.post_form_if_needed!
        items = form_message.content_attributes['items']
        expect(items.map { |i| i['name'] }).to eq(['name'])
      end
    end

    context 'when only email is missing' do
      before { contact.update!(name: 'Stefan Yoshovski') }

      it 'posts a form with only the Email field' do
        expect(Redis::Alfred).to receive(:set)
          .with("captain:contact_form:#{conversation.id}:email", 1, nx: true, ex: 7.days.to_i)
          .and_return('OK')

        form_message = service.post_form_if_needed!
        items = form_message.content_attributes['items']
        expect(items.map { |i| i['name'] }).to eq(['email'])
      end

      it 'does not post the form if the triggering message contains an email' do
        msg = build(:message, content: 'Handoff please, my email is stefan@example.com')
        expect(service.post_form_if_needed!(triggering_message: msg)).to be_nil
      end
    end

    context 'when neither is missing' do
      before do
        contact.update!(name: 'Stefan Yoshovski', email: 'stefan@example.com')
      end

      it 'does not post any form' do
        expect do
          expect(service.post_form_if_needed!).to be_nil
        end.not_to change(conversation.messages, :count)
      end
    end

    context 'when guard key is already set in Redis' do
      it 'does not repeat the form for the same combination of missing fields' do
        allow(Redis::Alfred).to receive(:set).and_return(nil)

        expect do
          expect(service.post_form_if_needed!).to be_nil
        end.not_to change(conversation.messages, :count)
      end
    end
  end

  describe '#handle_form_submission!' do
    let!(:form_message) do
      create(
        :message,
        conversation: conversation,
        account: account,
        inbox: inbox,
        content_type: :form,
        message_type: :outgoing,
        content: described_class::FORM_TEXT,
        content_attributes: {
          'type' => 'contact_capture',
          'items' => [
            { 'name' => 'name', 'label' => 'Name', 'type' => 'text' },
            { 'name' => 'email', 'label' => 'Email', 'type' => 'email' }
          ],
          'submitted_values' => [
            { 'name' => 'name', 'value' => 'Stefan Yoshovski' },
            { 'name' => 'email', 'value' => 'stefan@example.com' }
          ]
        }
      )
    end

    it 'saves submitted details to contact and replies with acknowledgement' do
      waiting_since = 10.minutes.ago
      conversation.update!(waiting_since: waiting_since)

      result = service.handle_form_submission!(form_message)
      expect(result).to be true

      contact.reload
      expect(contact.name).to eq('Stefan Yoshovski')
      expect(contact.email).to eq('stefan@example.com')

      acknowledgement = conversation.messages.outgoing.last
      expect(acknowledgement.content).to eq(described_class::ACKNOWLEDGEMENT_TEXT)
      expect(conversation.reload.waiting_since).to be_within(1.second).of(waiting_since)
      expect(form_message.reload.content_attributes['contact_details_saved']).to be true
    end

    it 'does not overwrite or merge if email exists on another contact' do
      create(:contact, account: account, email: 'stefan@example.com')

      service.handle_form_submission!(form_message)
      contact.reload
      expect(contact.name).to eq('Stefan Yoshovski')
      expect(contact.email).to be_nil
    end

    it 'does not process a second time for the same message' do
      service.handle_form_submission!(form_message)

      expect do
        result = service.handle_form_submission!(form_message.reload)
        expect(result).to be false
      end.not_to change(conversation.messages, :count)
    end
  end
end
