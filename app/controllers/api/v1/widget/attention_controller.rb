class Api::V1::Widget::AttentionController < Api::V1::Widget::BaseController
  KINDS = %w[activity snooze question check_in sound presented dismissed expired].freeze

  before_action :validate_attention_params

  def create
    return head :no_content unless conversation

    result = Widget::AttentionService.new(contact_inbox: @contact_inbox, conversation: conversation)
                                     .perform(kind: params[:kind], message_id: params[:message_id], event_id: params[:event_id])
    result ? render(json: result) : head(:no_content)
  end

  private

  def validate_attention_params
    ids_valid = [params[:message_id], params[:event_id]].all? { |id| id.nil? || id.is_a?(Integer) }
    head :unprocessable_entity unless KINDS.include?(params[:kind]) && ids_valid
  end
end
