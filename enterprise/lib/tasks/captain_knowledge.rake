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
  end
end
