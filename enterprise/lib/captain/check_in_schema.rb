class Captain::CheckInSchema < RubyLLM::Schema
  string :text, description: 'One short check-in for the visitor, in their language'
  array :suggested_replies, description: 'Optional relevant next step buttons for the customer' do
    object do
      string :label, description: 'Button text: 2 to 4 words, e.g. "Shipping info" or "Warranty details"'
      string :message, description: 'What the customer sends when clicking: the full question or request'
    end
  end
end
