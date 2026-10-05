namespace :captain do
  namespace :dify do
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
  end
end
