require 'rails_helper'

RSpec.describe Captain::Websites::BoilerplateLearner do
  it 'learns blocks repeated on a large share of a host' do
    learner = described_class.new
    5.times { |index| learner.add("https://www.example.com/page-#{index}", ['menu', "body-#{index}"]) }
    learner.add('https://blog.example.com/post', ['menu'])

    expect(learner.to_h).to eq('example.com' => ['menu'])
  end
end
