require 'rails_helper'

RSpec.describe Captain::Behaviour do
  it 'adapts the role, welcomes on the first reply and separates the follow-up on the widget' do
    expect(described_class::ROLE).to eq('adaptive')
    expect(described_class::WELCOME_ON_FIRST_REPLY).to be(true)
    expect(described_class::SEPARATE_FOLLOW_UP_ON_WIDGET).to be(true)
  end
end
