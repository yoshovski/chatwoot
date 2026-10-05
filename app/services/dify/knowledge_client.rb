require 'faraday/multipart'
require 'faraday/retry'

class Dify::KnowledgeClient
  class Error < StandardError
    attr_reader :status

    def initialize(message, status: nil)
      @status = status
      super(message)
    end
  end

  def initialize(base_url:, api_key:)
    @connection = Faraday.new(url: "#{base_url.chomp('/')}/v1/", headers: { 'Authorization' => "Bearer #{api_key}" }) do |connection|
      connection.request :multipart
      # Mutating POSTs are not retried: Dify does not offer an idempotency key.
      connection.request :retry, max: 2, interval: 0.5, backoff_factor: 2, methods: %i[get delete], retry_statuses: [429, 502, 503, 504]
      connection.options.open_timeout = 5
      connection.options.timeout = 60
      connection.adapter Faraday.default_adapter
    end
  end

  def create_dataset(**attributes)
    request(:post, 'datasets', attributes)
  end

  def dataset(dataset_id)
    request(:get, "datasets/#{dataset_id}")
  end

  def create_by_text(dataset_id:, **attributes)
    request(:post, "datasets/#{dataset_id}/document/create-by-text", attributes)
  end

  def create_by_file(dataset_id:, file:, filename:, content_type:, **attributes)
    upload = Faraday::Multipart::FilePart.new(file, content_type, filename)
    request(:post, "datasets/#{dataset_id}/document/create-by-file", { data: attributes.to_json, file: upload }, multipart: true)
  end

  def update_by_text(dataset_id:, document_id:, **attributes)
    request(:post, "datasets/#{dataset_id}/documents/#{document_id}/update-by-text", attributes)
  end

  def delete_document(dataset_id:, document_id:)
    request(:delete, "datasets/#{dataset_id}/documents/#{document_id}")
  end

  def indexing_status(dataset_id:, batch:)
    request(:get, "datasets/#{dataset_id}/documents/#{batch}/indexing-status")
  end

  def retrieve(dataset_id:, query:, retrieval_model:)
    request(:post, "datasets/#{dataset_id}/retrieve", { query: query, retrieval_model: retrieval_model })
  end

  private

  def request(method, path, payload = nil, multipart: false)
    response = @connection.run_request(method, path, nil, nil) do |request|
      request.headers['Content-Type'] = 'application/json' unless multipart
      request.body = multipart ? payload : payload&.to_json
    end
    raise Error.new("Dify request failed (HTTP #{response.status})", status: response.status) unless response.success?

    JSON.parse(response.body) unless response.body.to_s.empty?
  rescue Faraday::Error, JSON::ParserError
    # Response bodies and transport exceptions can contain credentials or private content.
    raise Error, 'Dify request failed', cause: nil
  end
end
