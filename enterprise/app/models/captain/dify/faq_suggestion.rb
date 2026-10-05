module Captain::Dify::FaqSuggestion
  extend ActiveSupport::Concern

  prepended do
    skip_callback :commit, :after, :update_embedding
  end
end
