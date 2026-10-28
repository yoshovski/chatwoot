json.payload do
  json.array! @gaps do |gap|
    json.partial! 'api/v1/models/captain/knowledge_gap', formats: [:json], resource: gap
    json.reasons do
      Captain::KnowledgeGapOccurrence::REASONS.each do |reason|
        json.set! reason, @reason_counts.fetch([gap.id, reason], 0)
      end
    end
  end
end

json.meta do
  json.total_count @gaps_count
  json.page @current_page
end
