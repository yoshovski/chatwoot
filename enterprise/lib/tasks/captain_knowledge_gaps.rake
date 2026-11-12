# rubocop:disable Metrics/BlockLength
namespace :captain do
  namespace :knowledge_gaps do
    gap_counts = lambda do |scope|
      {
        open: scope.open.count,
        unanswered: scope.unanswered.count,
        topics: scope.unanswered.distinct.count(:topic),
        action_requests: scope.open.action_request.count,
        unclassified: scope.unclassified.count
      }
    end

    desc 'Classify, rewrite and merge existing knowledge gaps (T18). Safe to stop and run again: it continues with the ' \
         'gaps still unclassified. Optional ACCOUNT_ID, LIMIT (gaps this run), PAUSE (seconds between model calls).'
    task backfill: :environment do
      scope = Captain::KnowledgeGap.all
      scope = scope.where(account_id: Integer(ENV.fetch('ACCOUNT_ID'))) if ENV['ACCOUNT_ID'].present?
      limit = ENV['LIMIT'].present? ? Integer(ENV.fetch('LIMIT')) : nil
      pause = Float(ENV.fetch('PAUSE', '0'))
      puts "before: #{gap_counts.call(scope)}"

      # Gaps recorded before T18 hold the raw customer text on the gap only. Copy it to their occurrences first, so the
      # text stays as an example and later messages with the same text find the gap after it is rewritten or merged.
      ActiveRecord::Base.connection.exec_update(<<~SQL.squish)
        UPDATE captain_knowledge_gap_occurrences o
        SET question = g.question, normalized_question = g.normalized_question
        FROM captain_knowledge_gaps g
        WHERE o.knowledge_gap_id = g.id AND o.question IS NULL AND g.kind = #{Captain::KnowledgeGap.kinds[:unclassified]}
        #{"AND g.account_id = #{Integer(ENV.fetch('ACCOUNT_ID'))}" if ENV['ACCOUNT_ID'].present?}
      SQL

      done = 0
      failed = 0
      scope.unclassified.find_each do |gap|
        break if limit && done + failed >= limit

        Captain::KnowledgeGaps::Classification.new(gap).perform
        done += 1
        print '.'
        sleep(pause) if pause.positive?
      rescue StandardError => e
        failed += 1
        puts "\ngap #{gap.id}: #{e.class.name}"
      end
      puts "\nclassified: #{done}, failed: #{failed}"
      puts "after: #{gap_counts.call(scope)}"
    end

    cosine_distance = lambda do |a, b|
      1 - (a.zip(b).sum { |x, y| x * y } / (Math.sqrt(a.sum { |x| x * x }) * Math.sqrt(b.sum { |x| x * x })))
    end

    desc 'Send the fixture messages to the real fast model and embedding model, group them like the merger does, and ' \
         'compare with the expected groups. Needs ACCOUNT_ID (for tenant tracking only). Writes nothing.'
    task eval: :environment do
      fixture = YAML.load_file(ENV.fetch('FIXTURE', Rails.root.join('spec/fixtures/files/captain/knowledge_gap_messages.yml')))
      account_id = Integer(ENV.fetch('ACCOUNT_ID'))
      embedder = Captain::Llm::EmbeddingService.new(account_id: account_id)
      topics = []
      groups = [] # { kind:, intent:, question:, vector:, members: [[expected_group, message]] }
      kind_hits = 0
      total = 0

      fixture.each do |expected_group, spec|
        spec['messages'].each do |message|
          result = Captain::KnowledgeGaps::Classifier.new(account_id: account_id, message: message, existing_topics: topics).classify
          topics |= [result.topic].compact
          vector = embedder.get_embedding(result.question)
          total += 1
          kind_hits += 1 if result.kind == spec['kind']
          puts format('%-16<expected>s %-14<kind>s %-13<intent>s %-26<topic>s %<question>s <- %<message>s',
                      expected: expected_group, kind: result.kind, intent: result.intent.to_s, topic: result.topic.to_s,
                      question: result.question, message: message.truncate(60))

          match = groups.select { |group| group[:kind] == result.kind && group[:intent] == result.intent }
                        .map { |group| [group, cosine_distance.call(group[:vector], vector)] }
                        .min_by(&:last)
          if match && match.last <= Captain::KnowledgeGaps::Merger::DISTANCE_THRESHOLD
            match.first[:members] << [expected_group, message]
          else
            groups << { kind: result.kind, intent: result.intent, question: result.question, vector: vector, members: [[expected_group, message]] }
          end
        end
      end

      puts "\nkinds right: #{kind_hits}/#{total}; groups: #{groups.size} (expected #{fixture.size})"
      groups.each do |group|
        expected = group[:members].map(&:first).uniq
        flag = expected.size == 1 && group[:members].size == fixture[expected.first]['messages'].size ? 'ok   ' : 'CHECK'
        puts "#{flag} #{group[:kind]} #{group[:question]} <- #{expected.join(', ')} (#{group[:members].size})"
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
