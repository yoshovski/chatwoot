namespace :captain do
  namespace :assistant do
    desc 'Apply assistant settings (prompts, rules, scenarios, FAQ replies) from a JSON file'
    task :import_settings, [:assistant_id, :path] => :environment do |_task, args|
      assistant = Captain::Assistant.find(args.fetch(:assistant_id))
      settings = JSON.parse(File.read(args.fetch(:path)))

      Captain::AssistantSettingsImporter.apply!(assistant: assistant, settings: settings)
      puts "Applied #{args[:path]} to Assistant ##{assistant.id} (#{assistant.name})"
    end
  end
end
