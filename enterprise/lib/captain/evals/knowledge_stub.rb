# Answers knowledge searches for an eval case from its fixture documents instead of Dify, in this process only.
# Direct-route searches run on other threads with their own database connection, which cannot see the case's
# uncommitted records, so the passages are built up front from the documents held in memory.
module Captain::Evals::KnowledgeStub
  TOP_PASSAGES = 6
  DATASET_ID = 'eval-fixture'.freeze
  @documents = Concurrent::Map.new

  module SearchOverride
    def search(query, kinds: nil)
      Captain::Evals::KnowledgeStub.registered?(@assistant.id) ? search_prepared(query, kinds: kinds) : super
    end

    def search_prepared(query, kinds: nil)
      return super unless Captain::Evals::KnowledgeStub.registered?(@assistant.id)

      Captain::Evals::KnowledgeStub.passages(@assistant.id, query)
    end
  end

  # The fixture documents stand in for a provisioned Dify knowledge base.
  module AccountOverride
    def dify_knowledge_enabled? = Captain::Evals::KnowledgeStub.account?(id) || super
  end

  module AssistantOverride
    def ensure_dify_datasets!
      super unless Captain::Evals::KnowledgeStub.registered?(id)
    end
  end

  class << self
    def install!
      Captain::Knowledge::Search.prepend(SearchOverride)
      Account.prepend(AccountOverride)
      Captain::Assistant.prepend(AssistantOverride)
    end

    def register(assistant, documents)
      @documents[assistant.id] = { account_id: assistant.account_id, documents: documents }
    end

    def clear = @documents.clear

    def registered?(assistant_id) = @documents.key?(assistant_id)

    def account?(account_id) = @documents.values.any? { |entry| entry[:account_id] == account_id }

    # Ranks the fixture documents by the share of query words they contain, like a small keyword search.
    def passages(assistant_id, query)
      terms = words(query)
      return [] if terms.empty?

      ranked = @documents.fetch(assistant_id)[:documents].filter_map do |document|
        score = (terms & words("#{document.name} #{document.content}")).size.fdiv(terms.size)
        passage(document, score) if score.positive?
      end
      ranked.sort_by { |item| -item.score }.first(TOP_PASSAGES)
    end

    private

    def passage(document, score)
      Captain::Knowledge::Search::Passage.new(
        kind: 'document', title: document.name, content: document.content, score: score.round(3), record: document,
        document_id: "eval-#{document.id}", dataset_id: DATASET_ID, source_url: document.external_link
      )
    end

    def words(text)
      text.to_s.downcase.scan(/[[:alnum:]]+/).select { |word| word.length > 2 } - Captain::Knowledge::Search::QUERY_FILLER
    end
  end
end
