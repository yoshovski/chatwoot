class Api::V1::Accounts::Captain::AgentSessionsController < Api::V1::Accounts::BaseController
  before_action :set_message
  before_action :authorize_conversation

  def show
    @agent_session = message_sessions.find_by(result_id: @message.id) || reply_session
    return head :not_found if @agent_session.blank?

    @citations = Current.account.captain_documents.where(id: @agent_session.cited_document_ids)
    @used_faqs = Current.account.captain_assistant_responses.approved.where(
      id: @agent_session.used_faq_ids,
      documentable_type: 'User'
    )
    @scenario_titles = Captain::Scenario.where(account_id: Current.account.id, id: @agent_session.scenario_ids)
                                        .pluck(:id, :title).to_h
    @sources = sources_with_document_links
  end

  private

  # Uploaded PDFs have no public page, so agents open the file itself from their source card.
  def sources_with_document_links
    files = document_file_links
    @agent_session.sources.map do |source|
      next source unless source['kind'] == 'document' && source['url'].blank? && files[source['document_id']]

      source.merge('url' => files[source['document_id']])
    end
  end

  def document_file_links
    Current.account.captain_documents.where(id: @agent_session.sources.pluck('document_id').compact)
           .to_h { |document| [document.id, document.display_url] }
           .select { |_id, link| link.to_s.match?(%r{\Ahttps?://}) }
  end

  def message_sessions
    Current.account.captain_agent_sessions.where(result_type: 'Message')
  end

  # One reply can post several Captain messages (answer, product cards, contact form),
  # but its session sits on just one of them, or on the handoff note. The dashboard
  # shows details on the last message of a group, so resolve a Captain message without
  # its own session to the latest earlier session with no customer message in between.
  def reply_session
    return unless @message.outgoing? && @message.sender_type == 'Captain::Assistant'

    session = message_sessions.where(subject: @message.conversation, result_id: ...@message.id).order(result_id: :desc).first
    return if session.blank?
    return if @message.conversation.messages.incoming.exists?(id: session.result_id...@message.id)

    session
  end

  def set_message
    @message = Current.account.messages.find(params[:id])
  end

  def authorize_conversation
    authorize @message.conversation, :show?
  end
end
