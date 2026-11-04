require 'rails_helper'

RSpec.describe Captain::Knowledge::VideoLink do
  describe '.label' do
    it 'names the video after its player title' do
      expect(described_class.label('Repot a fern', page_title: 'Fernbrook Gardens help')).to eq('Video: Repot a fern')
    end

    it 'names a video without a useful player title after the page it is on' do
      expect(described_class.label('Wistia video player', page_title: '  Repotting   guide ')).to eq('Watch: Repotting guide')
      expect(described_class.label(nil, page_title: 'Repotting guide')).to eq('Watch: Repotting guide')
    end

    it 'truncates the page title to 60 characters' do
      label = described_class.label(nil, page_title: 'How to repot, water and feed every fern in the Fernbrook Gardens catalogue')

      expect(label).to eq('Watch: How to repot, water and feed every fern in the Fernbrook ...')
      expect(label.delete_prefix('Watch: ').length).to eq(60)
    end

    it 'falls back to Video without a page title' do
      expect(described_class.label('', page_title: ' ')).to eq('Video')
    end
  end

  describe '.line?' do
    it 'recognises both labels' do
      expect(described_class.line?('[Watch: Repotting guide](https://www.youtube.com/watch?v=fern123abc)')).to be(true)
      expect(described_class.line?('[Video](https://vimeo.com/123456)')).to be(true)
      expect(described_class.line?('[Watch: Repotting guide](https://fernbrook.test/guide)')).to be(false)
    end
  end

  it 'uses the page title when the page reader keeps an untitled embed' do
    html = '<html><head><title>Repotting guide</title></head><body><main><p>Steps below.</p>' \
           '<iframe src="https://player.vimeo.com/video/123456" title="Vimeo video player"></iframe></main></body></html>'

    expect(Captain::Tools::HtmlPageParser.new(html).body_markdown).to include('[Watch: Repotting guide](https://vimeo.com/123456)')
  end
end
