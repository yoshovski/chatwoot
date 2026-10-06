namespace :captain do
  namespace :scanixx do
    desc 'Port Scanixx agent instructions, rules, quote scenario, and annotation replies to Captain settings'
    task :setup, [:assistant_id] => :environment do |_task, args|
      assistant = if args[:assistant_id].present?
                    Captain::Assistant.find(args[:assistant_id])
                  else
                    Captain::Assistant.find_by!(name: 'Captain lab T1 baseline')
                  end

      Captain::ScanixxConfigurator.apply!(assistant: assistant)
      puts "Successfully configured Scanixx settings for Assistant ##{assistant.id} (#{assistant.name})"
    end
  end
end
