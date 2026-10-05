Rails.application.config.to_prepare do
  Captain::Assistant.prepend Captain::Dify::Assistant if ChatwootApp.enterprise?
end
