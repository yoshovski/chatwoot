require 'rails_helper'

RSpec.describe Captain::Reply::Question do
  it 'removes every question sentence the text ends with' do
    expect(described_class.without_trailing('We have two. Which one? Which version do you need?')).to eq('We have two.')
  end

  it 'keeps decimals and abbreviations inside the question with it' do
    expect(described_class.without_trailing('The 3.5 model is new. Do you want the 3.5 version, e.g. for travel?'))
      .to eq('The 3.5 model is new.')
  end

  it 'handles CJK and Arabic question marks and line breaks' do
    expect(described_class.without_trailing('您可以暂停套餐。您使用的是哪个套餐？')).to eq('您可以暂停套餐。')
    expect(described_class.without_trailing("Steps:\n1. Open Settings.\nAnything else؟")).to eq("Steps:\n1. Open Settings.")
  end

  it 'leaves a text that does not end with a question and blanks one that only asks' do
    expect(described_class.without_trailing('Need help? Open Settings.')).to eq('Need help? Open Settings.')
    expect(described_class.without_trailing('How can I help?')).to eq('')
  end
end
