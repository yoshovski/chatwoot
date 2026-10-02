class Campaigns::CampaignConversationBuilder
  pattr_initialize [
    :contact_inbox_id!,
    :campaign_display_id!,
    :conversation_additional_attributes,
    :custom_attributes,
    :selected_response
  ]

  def perform
    @contact_inbox = ContactInbox.find(@contact_inbox_id)
    @campaign = @contact_inbox.inbox.campaigns.find_by!(display_id: campaign_display_id)

    ActiveRecord::Base.transaction do
      @contact_inbox.lock!

      # We won't send campaigns if a conversation is already present
      raise 'Conversation already present' if @contact_inbox.reload.conversations.present?

      @conversation = ::Conversation.create!(conversation_params)
      Messages::MessageBuilder.new(@campaign.sender, @conversation, message_params).perform
    end
    create_selected_response_message
    @conversation
  rescue StandardError => e
    Rails.logger.info(e.message)
    nil
  end

  private

  def message_params
    params = {
      content: @campaign.message,
      campaign_id: @campaign.id
    }
    # The visitor already picked a suggestion in the campaign bubble, so it is sent as their reply
    # below. Repeating the options here would invite them to answer the same question twice.
    if selected_item.blank? && suggested_response_items.present?
      params[:content_type] = 'input_select'
      params[:content_attributes] = { items: suggested_response_items }
    end

    ActionController::Parameters.new(params)
  end

  # ContentAttributeValidator only allows :title and :value on input_select items, so the
  # campaign's own response id is deliberately dropped here.
  def suggested_response_items
    @suggested_response_items ||= @campaign.suggested_responses.filter_map do |response|
      values = response.with_indifferent_access
      next if values[:enabled] == false || values[:title].blank?

      { title: values[:title], value: values[:title] }
    end
  end

  # The selection arrives from the public widget events endpoint, so it is only honoured when it
  # matches one of the campaign's own suggestions.
  def selected_item
    return @selected_item if defined?(@selected_item)

    title = selected_response.is_a?(Hash) ? selected_response.with_indifferent_access[:title].presence : nil
    @selected_item = title && suggested_response_items.find { |item| item[:title] == title }
  end

  # The selection has to land as a real incoming message: that is what agents, agent bots and
  # automations react to. Recording it on the campaign message alone would leave the conversation
  # without a visitor reply and nothing would answer it.
  def create_selected_response_message
    return if selected_item.blank?

    @conversation.messages.create!(
      account_id: @conversation.account_id,
      inbox_id: @conversation.inbox_id,
      sender: @contact_inbox.contact,
      message_type: :incoming,
      content: selected_item[:title]
    )
  end

  def conversation_params
    {
      account_id: @campaign.account_id,
      inbox_id: @contact_inbox.inbox_id,
      contact_id: @contact_inbox.contact_id,
      contact_inbox_id: @contact_inbox.id,
      campaign_id: @campaign.id,
      additional_attributes: conversation_additional_attributes,
      custom_attributes: custom_attributes || {}
    }
  end
end
