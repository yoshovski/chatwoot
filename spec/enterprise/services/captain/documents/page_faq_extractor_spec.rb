require 'rails_helper'

RSpec.describe Captain::Documents::PageFaqExtractor do
  describe '#extract' do
    it 'extracts FAQs from JSON-LD FAQPage script tags' do
      html = <<~HTML
        <html>
          <head>
            <script type="application/ld+json">
              {
                "@context": "https://schema.org",
                "@type": "FAQPage",
                "mainEntity": [
                  {
                    "@type": "Question",
                    "name": "What is the return window?",
                    "acceptedAnswer": {
                      "@type": "Answer",
                      "text": "<p>You have <strong>30 days</strong> to return items.</p>"
                    }
                  }
                ]
              }
            </script>
          </head>
          <body>
            <main><h1>Help Center</h1></main>
          </body>
        </html>
      HTML

      doc = Nokogiri::HTML(html)
      faqs = described_class.new(doc.at_css('main'), doc: doc).extract

      expect(faqs).to eq([
                           {
                             'question' => 'What is the return window?',
                             'answer' => 'You have **30 days** to return items.'
                           }
                         ])
    end

    it 'extracts FAQs from JSON-LD inside @graph' do
      html = <<~HTML
        <html>
          <head>
            <script type="application/ld+json">
              {
                "@context": "https://schema.org",
                "@graph": [
                  {
                    "@type": "WebPage",
                    "name": "Overview"
                  },
                  {
                    "@type": "FAQPage",
                    "mainEntity": [
                      {
                        "@type": "Question",
                        "name": "Can I exchange my size?",
                        "acceptedAnswer": {
                          "@type": "Answer",
                          "text": "Size exchanges are free of charge."
                        }
                      }
                    ]
                  }
                ]
              }
            </script>
          </head>
          <body>
            <main><h1>Help</h1></main>
          </body>
        </html>
      HTML

      doc = Nokogiri::HTML(html)
      faqs = described_class.new(doc.at_css('main'), doc: doc).extract

      expect(faqs).to eq([
                           {
                             'question' => 'Can I exchange my size?',
                             'answer' => 'Size exchanges are free of charge.'
                           }
                         ])
    end

    it 'extracts FAQs from microdata schema.org/Question items' do
      html = <<~HTML
        <html>
          <body>
            <main>
              <div itemscope itemtype="https://schema.org/Question">
                <h3 itemprop="name">How do I track my order?</h3>
                <div itemprop="acceptedAnswer" itemscope itemtype="https://schema.org/Answer">
                  <div itemprop="text">Use the tracking link in your email.</div>
                </div>
              </div>
            </main>
          </body>
        </html>
      HTML

      doc = Nokogiri::HTML(html)
      faqs = described_class.new(doc.at_css('main'), doc: doc).extract

      expect(faqs).to eq([
                           {
                             'question' => 'How do I track my order?',
                             'answer' => 'Use the tracking link in your email.'
                           }
                         ])
    end

    it 'extracts FAQs from details/summary elements' do
      html = <<~HTML
        <html>
          <body>
            <main>
              <details>
                <summary>Do you offer international shipping?</summary>
                <p>Yes, we ship to over 50 countries worldwide.</p>
              </details>
            </main>
          </body>
        </html>
      HTML

      doc = Nokogiri::HTML(html)
      faqs = described_class.new(doc.at_css('main'), doc: doc).extract

      expect(faqs).to eq([
                           {
                             'question' => 'Do you offer international shipping?',
                             'answer' => 'Yes, we ship to over 50 countries worldwide.'
                           }
                         ])
    end

    it 'extracts FAQs from ARIA accordions' do
      html = <<~HTML
        <html>
          <body>
            <main>
              <button aria-controls="faq-ans-1" aria-expanded="false">
                What payment methods are supported?
              </button>
              <div id="faq-ans-1" hidden>
                <p>We accept major credit cards and wire transfers.</p>
              </div>
            </main>
          </body>
        </html>
      HTML

      doc = Nokogiri::HTML(html)
      faqs = described_class.new(doc.at_css('main'), doc: doc).extract

      expect(faqs).to eq([
                           {
                             'question' => 'What payment methods are supported?',
                             'answer' => 'We accept major credit cards and wire transfers.'
                           }
                         ])
    end

    it 'extracts FAQs from dl elements when at least two dt end with ?' do
      html = <<~HTML
        <html>
          <body>
            <main>
              <dl>
                <dt>How long does delivery take?</dt>
                <dd>Standard delivery takes 3 to 5 business days.</dd>
                <dt>Can I change my address?</dt>
                <dd>Yes, within two hours of placing the order.</dd>
              </dl>
            </main>
          </body>
        </html>
      HTML

      doc = Nokogiri::HTML(html)
      faqs = described_class.new(doc.at_css('main'), doc: doc).extract

      expect(faqs).to eq([
                           {
                             'question' => 'How long does delivery take?',
                             'answer' => 'Standard delivery takes 3 to 5 business days.'
                           },
                           {
                             'question' => 'Can I change my address?',
                             'answer' => 'Yes, within two hours of placing the order.'
                           }
                         ])
    end

    it 'ignores dl elements when fewer than two dt end with ?' do
      html = <<~HTML
        <html>
          <body>
            <main>
              <dl>
                <dt>Author</dt>
                <dd>Staff Writer</dd>
                <dt>Do you agree?</dt>
                <dd>Please leave your feedback below.</dd>
              </dl>
            </main>
          </body>
        </html>
      HTML

      doc = Nokogiri::HTML(html)
      faqs = described_class.new(doc.at_css('main'), doc: doc).extract

      expect(faqs).to be_empty
    end

    it 'extracts FAQs from question headings when at least 3 headings end with ?' do
      html = <<~HTML
        <html>
          <body>
            <main>
              <h2>How do I register?</h2>
              <p>Click on the sign up link.</p>
              <h3>Where is my receipt?</h3>
              <p>Check your email confirmation.</p>
              <h4>Can I cancel anytime?</h4>
              <p>Yes, cancel from account settings.</p>
            </main>
          </body>
        </html>
      HTML

      doc = Nokogiri::HTML(html)
      faqs = described_class.new(doc.at_css('main'), doc: doc).extract

      expect(faqs).to eq([
                           {
                             'question' => 'How do I register?',
                             'answer' => 'Click on the sign up link.'
                           },
                           {
                             'question' => 'Where is my receipt?',
                             'answer' => 'Check your email confirmation.'
                           },
                           {
                             'question' => 'Can I cancel anytime?',
                             'answer' => 'Yes, cancel from account settings.'
                           }
                         ])
    end

    it 'ignores question headings when fewer than 3 headings end with ?' do
      html = <<~HTML
        <html>
          <body>
            <main>
              <h2>How do I register?</h2>
              <p>Click on the sign up link.</p>
              <h2>Where is my receipt?</h2>
              <p>Check your email confirmation.</p>
            </main>
          </body>
        </html>
      HTML

      doc = Nokogiri::HTML(html)
      faqs = described_class.new(doc.at_css('main'), doc: doc).extract

      expect(faqs).to be_empty
    end

    it 'deduplicates questions normalizing downcase, whitespace and trailing ?' do
      html = <<~HTML
        <html>
          <head>
            <script type="application/ld+json">
              {
                "@context": "https://schema.org",
                "@type": "FAQPage",
                "mainEntity": [
                  {
                    "@type": "Question",
                    "name": "How do I reset my password?",
                    "acceptedAnswer": {
                      "@type": "Answer",
                      "text": "Click reset password on login."
                    }
                  }
                ]
              }
            </script>
          </head>
          <body>
            <main>
              <details>
                <summary>  HOW DO I RESET MY PASSWORD?  </summary>
                <p>Click reset password on login page.</p>
              </details>
            </main>
          </body>
        </html>
      HTML

      doc = Nokogiri::HTML(html)
      faqs = described_class.new(doc.at_css('main'), doc: doc).extract

      expect(faqs.size).to eq(1)
      expect(faqs.first['question']).to eq('How do I reset my password?')
    end

    it 'drops questions that do not meet length requirements or have empty answers' do
      html = <<~HTML
        <html>
          <body>
            <main>
              <details>
                <summary>Why?</summary>
                <p>Too short question.</p>
              </details>
              <details>
                <summary>Valid question title?</summary>
                <p></p>
              </details>
              <details>
                <summary>Valid question with answer?</summary>
                <p>Valid answer text.</p>
              </details>
            </main>
          </body>
        </html>
      HTML

      doc = Nokogiri::HTML(html)
      faqs = described_class.new(doc.at_css('main'), doc: doc).extract

      expect(faqs).to eq([
                           {
                             'question' => 'Valid question with answer?',
                             'answer' => 'Valid answer text.'
                           }
                         ])
    end
  end
end
