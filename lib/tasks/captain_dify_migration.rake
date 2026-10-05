namespace :captain do
  namespace :dify do
    desc 'Convert a text FAQ dataset to native Q&A. Retry while indexing. Usage: rake captain:dify:migrate_faqs ASSISTANT_ID=123'
    task migrate_faqs: :environment do
      assistant = Captain::Assistant.find(ENV.fetch('ASSISTANT_ID'))
      raise 'Configure the account Dify workspace before migrating FAQs' unless assistant.account.dify_knowledge_enabled?

      Captain::Dify::FaqDatasetMigrationService.new(assistant).perform
      puts "Native Q&A FAQ dataset ready for assistant_id=#{assistant.id}; run captain:dify:backfill_faqs to sync subsequent changes"
    end
  end
end
