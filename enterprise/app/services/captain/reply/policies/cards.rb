# The order card and the product cards follow the answer. With cards, the suggestion buttons come after all cards,
# with the closing question; without buttons the question stays in the answer.
class Captain::Reply::Policies::Cards < Captain::Reply::Policies::Base
  def apply
    move_buttons_after_cards if workspace.buttons && !workspace.closing && workspace.contains_cards?
    cards = workspace.order_card_payloads.map { |payload| Captain::Reply::Segment.from_payload('order_card', payload) } +
            workspace.product_card_payloads.map { |payload| Captain::Reply::Segment.from_payload('product_cards', payload) }
    workspace.closing ? workspace.segments.insert(-2, *cards) : workspace.segments.concat(cards)
  end

  private

  def move_buttons_after_cards
    index = workspace.answer_index
    workspace.segments[index] = workspace.without_buttons(workspace.segments[index])
    workspace.close_with_question!
    workspace.segments[-1] = workspace.with_buttons(workspace.segments[-1])
  end
end
