require 'rails_helper'

RSpec.describe Captain::Documents::CrawlJob, type: :job do
  let(:document) { create(:captain_document, external_link: 'https://example.com/page') }
  let(:assistant_id) { document.assistant_id }
  let(:webhook_url) { Rails.application.routes.url_helpers.enterprise_webhooks_firecrawl_url }

  describe '#perform' do
    context 'when CAPTAIN_FIRECRAWL_API_KEY is configured' do
      let(:firecrawl_service) { instance_double(Captain::Tools::FirecrawlService) }
      let(:account) { document.account }
      let(:token) { Digest::SHA256.hexdigest("-key#{document.assistant_id}#{document.account_id}") }

      before do
        allow(Captain::Tools::FirecrawlService).to receive(:new).and_return(firecrawl_service)
        allow(firecrawl_service).to receive(:perform)
        create(:installation_config, name: 'CAPTAIN_FIRECRAWL_API_KEY', value: 'test-key')
      end

      context 'with account usage limits' do
        before do
          allow(account).to receive(:usage_limits).and_return({ captain: { documents: { current_available: 20 } } })
        end

        it 'uses FirecrawlService with the correct crawl limit' do
          expect(firecrawl_service).to receive(:perform).with(
            document.external_link,
            "#{webhook_url}?assistant_id=#{assistant_id}&token=#{token}",
            20,
            include_paths: []
          )

          described_class.perform_now(document)
        end
      end

      context 'when crawl limit exceeds maximum' do
        before do
          allow(account).to receive(:usage_limits).and_return({ captain: { documents: { current_available: 1000 } } })
        end

        it 'caps the crawl limit at 500' do
          expect(firecrawl_service).to receive(:perform).with(
            document.external_link,
            "#{webhook_url}?assistant_id=#{assistant_id}&token=#{token}",
            500,
            include_paths: []
          )

          described_class.perform_now(document)
        end
      end

      context 'with no usage limits configured' do
        before do
          allow(account).to receive(:usage_limits).and_return({})
        end

        it 'uses default crawl limit of 10' do
          expect(firecrawl_service).to receive(:perform).with(
            document.external_link,
            "#{webhook_url}?assistant_id=#{assistant_id}&token=#{token}",
            10,
            include_paths: []
          )

          described_class.perform_now(document)
        end
      end
    end

    context 'when CAPTAIN_FIRECRAWL_API_KEY is not configured' do
      let(:page_links) { ['https://example.com/page1', 'https://example.com/page2'] }
      let(:simple_crawler) { instance_double(Captain::Tools::SimplePageCrawlService) }

      before do
        allow(Captain::Tools::SimplePageCrawlService)
          .to receive(:new)
          .with(document.external_link)
          .and_return(simple_crawler)

        allow(simple_crawler).to receive(:page_links).and_return(page_links)
      end

      it 'enqueues SimplePageCrawlParserJob for each discovered link, a few seconds apart' do
        freeze_time do
          described_class.perform_now(document)

          page_links.each_with_index do |link, index|
            expect(Captain::Tools::SimplePageCrawlParserJob).to have_been_enqueued
              .with(assistant_id: assistant_id, page_link: link).at(((index + 1) * 2).seconds.from_now)
          end
          # Should also crawl the original link
          expect(Captain::Tools::SimplePageCrawlParserJob).to have_been_enqueued
            .with(assistant_id: assistant_id, page_link: document.external_link)
        end
      end

      it 'uses SimplePageCrawlService to discover page links' do
        expect(simple_crawler).to receive(:page_links)
        described_class.perform_now(document)
      end

      it 'skips links to other sites' do
        allow(simple_crawler).to receive(:page_links).and_return(['https://example.com/page1', 'https://facebook.com/example'])

        described_class.perform_now(document)

        expect(Captain::Tools::SimplePageCrawlParserJob).not_to have_been_enqueued
          .with(assistant_id: assistant_id, page_link: 'https://facebook.com/example')
        expect(Captain::Tools::SimplePageCrawlParserJob).to have_been_enqueued.twice
      end

      it 'adds only the page itself when linked pages are off' do
        document.update!(include_linked_pages: 'false')

        described_class.perform_now(document)

        expect(Captain::Tools::SimplePageCrawlService).not_to have_received(:new)
        expect(Captain::Tools::SimplePageCrawlParserJob).to have_been_enqueued
          .once.with(assistant_id: assistant_id, page_link: document.external_link)
      end

      it 'marks the document as failed when the crawl crashes' do
        allow(simple_crawler).to receive(:page_links).and_raise(URI::InvalidURIError, 'bad URI')

        expect { described_class.perform_now(document) }.to raise_error(URI::InvalidURIError)
        expect(document.reload).to have_attributes(status: 'available', sync_status: 'failed', last_sync_error_code: 'fetch_failed')
      end
    end

    context 'when document is a PDF' do
      let(:pdf_document) do
        doc = create(:captain_document, external_link: 'https://example.com/document')
        allow(doc).to receive(:pdf_document?).and_return(true)
        allow(doc).to receive(:update!).and_return(true)
        doc
      end

      it 'processes PDF using PdfProcessingService' do
        pdf_service = instance_double(Captain::Llm::PdfProcessingService)
        expect(Captain::Llm::PdfProcessingService).to receive(:new).with(pdf_document).and_return(pdf_service)
        expect(pdf_service).to receive(:process)
        expect(pdf_document).not_to receive(:update!).with(status: :available)

        described_class.perform_now(pdf_document)
      end

      it 'handles PDF processing errors' do
        allow(Captain::Llm::PdfProcessingService).to receive(:new).and_raise(StandardError, 'Processing failed')

        expect { described_class.perform_now(pdf_document) }.to raise_error(StandardError, 'Processing failed')
      end
    end
  end
end
