# rubocop:disable Metrics/BlockLength
namespace :captain do
  namespace :dify do
    desc 'Enqueue document sync to Dify for one assistant. Usage: rake captain:dify:backfill_documents ASSISTANT_ID=123'
    task backfill_documents: :environment do
      assistant = Captain::Assistant.find(ENV.fetch('ASSISTANT_ID'))
      raise 'Configure the account Dify workspace before backfilling documents' unless assistant.account.dify_knowledge_enabled?

      assistant.ensure_dify_datasets!
      count = 0
      assistant.documents.find_each do |document|
        if document.pdf_document? || document.content.present?
          Captain::Dify::SyncDocumentJob.perform_later(document.id)
        else
          Captain::Documents::CrawlJob.perform_later(document)
        end
        count += 1
      end
      puts "Enqueued #{count} document sync jobs for assistant_id=#{assistant.id}"
    end

    desc 'Give every AI agent\'s Dify datasets a readable name and description. Optional: ACCOUNT_ID=123'
    task describe_datasets: :environment do
      scope = Captain::Assistant.all
      scope = scope.where(account_id: ENV['ACCOUNT_ID']) if ENV['ACCOUNT_ID'].present?
      count = 0
      scope.find_each do |assistant|
        next unless assistant.account.dify_knowledge_enabled?

        Captain::Dify::DescribeDatasetsJob.perform_now(assistant.id)
        count += 1
      rescue Dify::KnowledgeClient::Error => e
        puts "assistant_id=#{assistant.id}: #{e.message}"
      end
      puts "Described the Dify datasets of #{count} assistants"
    end

    desc 'Enqueue FAQ sync to Dify for one assistant. Usage: rake captain:dify:backfill_faqs ASSISTANT_ID=123'
    task backfill_faqs: :environment do
      assistant = Captain::Assistant.find(ENV.fetch('ASSISTANT_ID'))
      raise 'Configure the account Dify workspace before backfilling FAQs' unless assistant.account.dify_knowledge_enabled?

      assistant.ensure_dify_datasets!
      count = 0
      assistant.responses.find_each do |response|
        Captain::Dify::SyncFaqJob.perform_later(response.id)
        count += 1
      end
      puts "Enqueued #{count} FAQ sync jobs for assistant_id=#{assistant.id}"
    end

    desc 'Re-sync text documents whose Dify index predates section-aware chunking. Optional: ACCOUNT_ID=123'
    task resection_documents: :environment do
      scope = Captain::Document.where("metadata->>'dify_document_id' IS NOT NULL")
      scope = scope.where(account_id: ENV['ACCOUNT_ID']) if ENV['ACCOUNT_ID'].present?
      count = 0
      scope.find_each do |document|
        next if document.pdf_document? || document.dify_content_fingerprint == document.dify_source_fingerprint

        Captain::Dify::SyncDocumentJob.perform_later(document.id)
        count += 1
      end
      puts "Enqueued #{count} document sync jobs"
    end
  end
end
# rubocop:enable Metrics/BlockLength
