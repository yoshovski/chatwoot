require 'rails_helper'

RSpec.describe Captain::Tools::HtmlPageParser do
  describe '#title' do
    it 'returns the page title stripped of whitespace' do
      parser = described_class.new('<html><head><title>  Sample Title  </title></head></html>')
      expect(parser.title).to eq('Sample Title')
    end

    it 'returns nil when title tag is missing' do
      parser = described_class.new('<html><head></head><body>Hello</body></html>')
      expect(parser.title).to be_nil
    end
  end

  describe '#body_markdown' do
    it 'keeps only main content from a page with a header menu, announcement bar, main text, and footer' do
      html = <<~HTML
        <html>
          <body>
            <header>
              <nav><a href="/home">Home</a><a href="/about">About</a></nav>
            </header>
            <div class="announcement-bar">Free shipping this weekend!</div>
            <main>
              <h1>Product Documentation</h1>
              <p>This is the primary product overview text.</p>
            </main>
            <footer>
              <p>&copy; 2026 Example Corp. All rights reserved.</p>
            </footer>
          </body>
        </html>
      HTML

      parser = described_class.new(html)
      markdown = parser.body_markdown

      expect(markdown).to include('# Product Documentation')
      expect(markdown).to include('This is the primary product overview text.')
      expect(markdown).not_to include('Home')
      expect(markdown).not_to include('About')
      expect(markdown).not_to include('Free shipping')
      expect(markdown).not_to include('Example Corp')
    end

    it 'falls back to body minus nav, header, footer, and scripts when main and article tags are absent' do
      html = <<~HTML
        <html>
          <body>
            <header>
              <div class="site-header">Header Title</div>
            </header>
            <nav>
              <ul><li>Navigation Item</li></ul>
            </nav>
            <div class="content">
              <h1>General Page</h1>
              <p>Standard body content lives here.</p>
            </div>
            <script>alert("test");</script>
            <style>.test { color: red; }</style>
            <footer>
              <div>Footer information</div>
            </footer>
          </body>
        </html>
      HTML

      parser = described_class.new(html)
      markdown = parser.body_markdown

      expect(markdown).to include('# General Page')
      expect(markdown).to include('Standard body content lives here.')
      expect(markdown).not_to include('Header Title')
      expect(markdown).not_to include('Navigation Item')
      expect(markdown).not_to include('alert')
      expect(markdown).not_to include('Footer information')
    end

    it 'falls back to body when two article elements exist, keeping both articles' do
      html = <<~HTML
        <html>
          <body>
            <header><h1>Blog Header</h1></header>
            <div class="posts">
              <article>
                <h2>First Article</h2>
                <p>Content of the first article.</p>
              </article>
              <article>
                <h2>Second Article</h2>
                <p>Content of the second article.</p>
              </article>
            </div>
            <footer>Footer note</footer>
          </body>
        </html>
      HTML

      parser = described_class.new(html)
      markdown = parser.body_markdown

      expect(markdown).to include('## First Article')
      expect(markdown).to include('Content of the first article.')
      expect(markdown).to include('## Second Article')
      expect(markdown).to include('Content of the second article.')
      expect(markdown).not_to include('Blog Header')
      expect(markdown).not_to include('Footer note')
    end

    it 'uses a single article element as main content when exactly one exists' do
      html = <<~HTML
        <html>
          <body>
            <header><p>Site Header</p></header>
            <article>
              <h1>Solo Article</h1>
              <p>Single article body.</p>
            </article>
            <footer><p>Site Footer</p></footer>
          </body>
        </html>
      HTML

      parser = described_class.new(html)
      markdown = parser.body_markdown

      expect(markdown).to include('# Solo Article')
      expect(markdown).to include('Single article body.')
      expect(markdown).not_to include('Site Header')
      expect(markdown).not_to include('Site Footer')
    end

    it 'uses role="main" element when main tag is absent' do
      html = <<~HTML
        <html>
          <body>
            <header>Header info</header>
            <div role="main">
              <h1>Role Main Title</h1>
              <p>Content inside role main.</p>
            </div>
            <footer>Footer info</footer>
          </body>
        </html>
      HTML

      parser = described_class.new(html)
      markdown = parser.body_markdown

      expect(markdown).to include('# Role Main Title')
      expect(markdown).to include('Content inside role main.')
      expect(markdown).not_to include('Header info')
      expect(markdown).not_to include('Footer info')
    end

    it 'removes noise elements matching noise tokens in class or id' do
      html = <<~HTML
        <html>
          <body>
            <main>
              <div id="cookie-consent">Accept our cookies</div>
              <div class="newsletter-signup">Subscribe to newsletter</div>
              <div class="modal-dialog">Popup modal</div>
              <div class="side-drawer">Drawer menu</div>
              <div class="breadcrumb-trail">Home / Products</div>
              <div class="popup-box">Special offer popup</div>
              <h1>Clean Document</h1>
              <p>Keep this content.</p>
            </main>
          </body>
        </html>
      HTML

      parser = described_class.new(html)
      markdown = parser.body_markdown

      expect(markdown.strip).to eq("# Clean Document\n\nKeep this content.")
    end

    it 'preserves elements whose class or id contains target substrings as unrelated words' do
      html = <<~HTML
        <html>
          <body>
            <main>
              <div class="multimodal-analysis">Multimodal analysis content</div>
              <div class="bookie-odds">Bookie odds content</div>
              <div class="withdrawer-profile">Withdrawer profile content</div>
            </main>
          </body>
        </html>
      HTML

      parser = described_class.new(html)
      markdown = parser.body_markdown

      expect(markdown).to include('Multimodal analysis content')
      expect(markdown).to include('Bookie odds content')
      expect(markdown).to include('Withdrawer profile content')
    end

    it 'does not mutate the parsed document when extracting markdown' do
      html = <<~HTML
        <html>
          <body>
            <header>
              <a href="https://example.com/menu">Menu Link</a>
            </header>
            <main>
              <p>Main content <a href="https://example.com/inner">Inner Link</a></p>
            </main>
          </body>
        </html>
      HTML

      parser = described_class.new(html)
      parser.body_markdown

      expect(parser.doc.xpath('//a/@href').map(&:value)).to contain_exactly(
        'https://example.com/menu',
        'https://example.com/inner'
      )
    end

    it 'collapses 3 or more blank lines into 2' do
      html = <<~HTML
        <html>
          <body>
            <main>
              <p>First paragraph</p>
              <br><br><br><br>
              <p>Second paragraph</p>
            </main>
          </body>
        </html>
      HTML

      parser = described_class.new(html)
      markdown = parser.body_markdown

      expect(markdown).not_to match(/(?:\n[ \t]*){3,}\n/)
      expect(markdown).to include("First paragraph\n\n\nSecond paragraph")
    end
  end
end
