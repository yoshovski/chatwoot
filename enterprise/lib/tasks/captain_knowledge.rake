# rubocop:disable Metrics/BlockLength
namespace :captain do
  namespace :knowledge do
    desc 'Reindex selected account-owned text documents with the current section chunking'
    task reindex_sections: :environment do
      account = Account.find(Integer(ENV.fetch('ACCOUNT_ID')))
      raise 'Dify knowledge is not configured for this account' unless account.dify_knowledge_enabled?

      ids = ENV.fetch('DOCUMENT_IDS').split(',').map { |id| Integer(id) }.uniq
      raise 'DOCUMENT_IDS must contain at least one document' if ids.empty?

      documents = Captain::Document.for_account(account.id).enabled.where(id: ids).to_a
      raise 'Documents must all be enabled and owned by ACCOUNT_ID' unless documents.size == ids.size
      raise 'Section reindexing supports text documents only' if documents.any?(&:pdf_document?)

      documents.each { |document| Captain::Dify::SyncDocumentJob.perform_later(document.id) }
      puts "Queued section reindexing for account #{account.id}: #{ids.join(',')}"
    end

    desc 'Move one agent to knowledge processing version 3: re-clean its website pages from the stored crawl and repack its chunks'
    task upgrade_processing: :environment do
      account = Account.find(Integer(ENV.fetch('ACCOUNT_ID')))
      raise 'Dify knowledge is not configured for this account' unless account.dify_knowledge_enabled?

      assistant = account.captain_assistants.find(Integer(ENV.fetch('ASSISTANT_ID')))
      assistant.update!(config: assistant.config.merge('knowledge_processing_version' => 3))
      assistant.documents.enabled.where.not(external_link: nil).find_each do |document|
        # Pages crawled before version 2 stored no separate raw text; their content is the crawl.
        raw = document.metadata.to_h['raw_crawl_content'] || document.content
        next if document.pdf_document? || raw.blank?

        document.update!(content: Captain::Documents::PageKnowledgeProcessor.new(document).perform(raw))
        Captain::Dify::SyncDocumentJob.perform_later(document.id)
      rescue StandardError => e
        puts "Document #{document.id} was not re-cleaned: #{e.class.name}"
      end
      puts "Agent #{assistant.id} is on processing version 3; Dify reindexing queued"
    end

    desc 'Delete unedited AI-generated FAQs of one agent whose answer repeats another FAQ (DRY_RUN=1 only lists them)'
    task dedupe_generated_faqs: :environment do
      account = Account.find(Integer(ENV.fetch('ACCOUNT_ID')))
      assistant = account.captain_assistants.find(Integer(ENV.fetch('ASSISTANT_ID')))
      dry_run = ENV['DRY_RUN'] == '1'
      responses = assistant.responses.order(:id).to_a
      keep = responses.reject { |response| response.origin == 'ai_generated' && !response.edited }
                      .to_set { |response| response.answer.to_s.gsub(/\s+/, ' ').strip.downcase }
      duplicates = responses.select do |response|
        next false unless response.origin == 'ai_generated' && !response.edited

        !keep.add?(response.answer.to_s.gsub(/\s+/, ' ').strip.downcase)
      end
      duplicates.each { |response| puts "#{dry_run ? 'Would delete' : 'Deleting'} FAQ #{response.id}: #{response.question.first(80)}" }
      duplicates.each(&:destroy!) unless dry_run
      puts "#{duplicates.size} of #{responses.size} FAQs #{dry_run ? 'would be' : 'were'} deleted for agent #{assistant.id}"
    end
  end
end
# rubocop:enable Metrics/BlockLength
