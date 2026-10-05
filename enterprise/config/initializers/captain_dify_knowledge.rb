Rails.application.config.to_prepare do
  if ChatwootApp.enterprise?
    Captain::Assistant.prepend Captain::Dify::Assistant
    Captain::AssistantResponse.prepend Captain::Dify::AssistantResponse
    Captain::FaqSuggestion.prepend Captain::Dify::FaqSuggestion
    Captain::Document.prepend Captain::Dify::Document
    Captain::Documents::CrawlJob.prepend Captain::Dify::DocumentCrawlJob
    Captain::Documents::ResponseBuilderJob.prepend Captain::Dify::DocumentResponseBuilderJob
    Captain::Documents::SyncService.prepend Captain::Dify::DocumentSync
    Captain::Llm::PdfProcessingService.prepend Captain::Dify::PdfProcessingService
  end
end
