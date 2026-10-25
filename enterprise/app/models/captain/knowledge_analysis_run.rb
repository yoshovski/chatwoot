class Captain::KnowledgeAnalysisRun < ApplicationRecord
  self.table_name = 'captain_knowledge_analysis_runs'
  STATUSES = %w[pending running completed budget_stopped failed].freeze

  belongs_to :account
  belongs_to :assistant, class_name: 'Captain::Assistant'

  before_validation -> { self.account = assistant.account if assistant }
  validates :corpus_fingerprint, presence: true
  validates :status, inclusion: { in: STATUSES }

  def total_tokens
    input_tokens.to_i + output_tokens.to_i
  end

  def reserve_tokens!(estimated_tokens)
    amount = [estimated_tokens.to_i, 0].max
    with_lock do
      if token_budget.present? && (total_tokens + reserved_tokens.to_i + amount > token_budget)
        update!(status: 'budget_stopped', completed_at: Time.current) if status.in?(%w[pending running])
        return false
      end

      update!(reserved_tokens: reserved_tokens.to_i + amount, status: 'running', started_at: started_at || Time.current)
      true
    end
  end

  def reconcile_tokens!(reserved:, input: 0, output: 0, **extra)
    with_lock do
      update!(reconciled_token_counts(reserved, input, output).merge(reconciled_call_counts(extra)))
    end
  end

  def reconciled_token_counts(reserved, input, output)
    {
      reserved_tokens: [reserved_tokens.to_i - reserved.to_i, 0].max,
      input_tokens: input_tokens.to_i + input.to_i,
      output_tokens: output_tokens.to_i + output.to_i
    }
  end

  def reconciled_call_counts(extra)
    {
      cached_tokens: cached_tokens.to_i + extra[:cached].to_i,
      calls_count: calls_count.to_i + (extra[:calls] || 1).to_i,
      retries_count: retries_count.to_i + extra[:retries].to_i
    }
  end

  def cost_report(input_rate: nil, output_rate: nil)
    cost_usd = (input_tokens.to_i * input_rate.to_f) + (output_tokens.to_i * output_rate.to_f) if input_rate && output_rate
    {
      'status' => status,
      'model' => llm_model,
      'analysis_version' => analysis_version,
      'corpus_fingerprint' => corpus_fingerprint,
      'token_budget' => token_budget,
      'reserved_tokens' => reserved_tokens,
      'input_tokens' => input_tokens,
      'output_tokens' => output_tokens,
      'cached_tokens' => cached_tokens,
      'calls' => calls_count,
      'retries' => retries_count,
      'cost_usd' => cost_usd&.round(6),
      'currency_status' => cost_usd ? 'measured' : 'unknown'
    }
  end
end
