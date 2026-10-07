# RubyLLM caches the first model registry it loads. Set the committed registry at boot so every
# caller (Captain v2 agents, Llm::Config and task services) resolves models from the same file.
RubyLLM.configure do |config|
  config.model_registry_file = Rails.root.join('config/llm_models.json').to_s
end
