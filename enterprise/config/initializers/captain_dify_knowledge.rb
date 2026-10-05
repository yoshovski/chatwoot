Rails.application.config.to_prepare do
  if ChatwootApp.enterprise?
    Captain::Assistant.prepend Captain::Dify::Assistant
    Captain::AssistantResponse.prepend Captain::Dify::AssistantResponse
    Captain::FaqSuggestion.prepend Captain::Dify::FaqSuggestion
  end
end
