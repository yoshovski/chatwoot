namespace :captain do
  namespace :dify do
    desc 'Re-upload documents and FAQs whose Dify copy is missing. Usage: rake captain:dify:reconcile ASSISTANT_ID=123'
    task reconcile: :environment do
      assistant = Captain::Assistant.find(ENV.fetch('ASSISTANT_ID'))
      result = Captain::Dify::ReconcileService.new(assistant).perform
      puts "Re-syncing #{result[:documents]} documents and #{result[:faqs]} FAQs for assistant_id=#{assistant.id}"
    end
  end
end
