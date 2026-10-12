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
  end
end
