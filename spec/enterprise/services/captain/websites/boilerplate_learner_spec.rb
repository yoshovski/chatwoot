require 'rails_helper'

RSpec.describe Captain::Websites::BoilerplateLearner do
  it 'learns blocks repeated on a large share of a host' do
    learner = described_class.new
    5.times { |index| learner.add("https://www.example.com/page-#{index}", ['menu', "body-#{index}"]) }
    learner.add('https://blog.example.com/post', ['menu'])

    expect(learner.to_h).to eq('example.com' => ['menu'])
  end

  it 'learns a banner repeated within one section and keeps it on the section start' do
    learner = described_class.new
    20.times { |index| learner.add("https://www.example.com/docs/page-#{index}", ["docs-#{index}"]) }
    %w[a b c d].each { |slug| learner.add("https://www.example.com/resources/#{slug}-guide", ['ebook', "#{slug}-body"]) }
    learner.add('https://www.example.com/resources', ['ebook'])
    learner.add('https://www.example.com/resources/e-guide', ['e-body'])

    expect(learner.to_h).to eq({})
    expect(learner.sections).to eq('example.com/resources' => { 'keep' => 'https://www.example.com/resources', 'blocks' => ['ebook'] })
  end
end
