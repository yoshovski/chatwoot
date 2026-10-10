class AccountDataExportService
  def initialize(export:, tar:)
    @export = export
    @account = export.account
    @tar = tar
  end

  def perform
    add('manifest.json', { schema_version: 1, account_id: @account.id, generated_at: Time.current,
                           export_type: @export.export_type,
                           excluded: %w[shopify_product_catalog credentials assistant_instructions internal_strategy] }.to_json)
    conversations if include?('conversations')
    contacts if include?('contacts')
    knowledge if include?('knowledge')
  end

  private

  def include?(type)
    @export.export_type == 'all' || @export.export_type == type
  end

  def add(name, content)
    @tar.add_file_simple(name, 0o600, content.bytesize) { |entry| entry.write(content) }
  end

  def json_lines(name, records, fields)
    Tempfile.create('export-records') do |file|
      records.find_each do |record|
        data = record.attributes.slice(*fields)
        data.merge!(yield(record)) if block_given?
        file.puts(data.to_json)
      end
      file.flush
      file.rewind
      @tar.add_file_simple(name, 0o600, file.size) { |entry| IO.copy_stream(file, entry) }
    end
  end

  def conversations
    json_lines('conversations.jsonl', @account.conversations,
               %w[id display_id contact_id inbox_id status created_at updated_at])
    json_lines('messages.jsonl', @account.messages,
               %w[id conversation_id sender_id sender_type message_type content private created_at updated_at])
    attachments
  end

  def attachments
    records = Attachment.where(account: @account).includes(file_attachment: :blob)
    json_lines('attachments.jsonl', records, %w[id message_id file_type coordinates_lat coordinates_long fallback_title]) do |attachment|
      original_metadata(attachment.file, "attachments/#{attachment.id}/original")
    end
    records.find_each { |attachment| attach_original(attachment.file, "attachments/#{attachment.id}/original") }
  end

  def contacts
    json_lines('contacts.jsonl', @account.contacts,
               %w[id name email phone_number identifier company_name custom_attributes additional_attributes created_at updated_at])
  end

  def knowledge
    json_lines('knowledge/articles.jsonl', @account.articles, %w[id portal_id category_id title slug content status created_at updated_at])
    captain_knowledge if ChatwootApp.enterprise?
    native_knowledge if @account.feature_enabled?('native_ai_knowledge')
  end

  def captain_knowledge
    documents = Captain::Document.where(account: @account, agents_only: false)
    json_lines('knowledge/documents.jsonl', documents, %w[id assistant_id name content external_link enabled created_at updated_at]) do |document|
      original_metadata(document.attached_file, "knowledge/originals/#{document.id}/original")
    end
    json_lines('knowledge/faqs.jsonl', Captain::AssistantResponse.where(account: @account, agents_only: false).where(
                                         "documentable_type IS DISTINCT FROM 'Captain::Document' OR documentable_id IN (?)", documents.select(:id)
                                       ), %w[id assistant_id question answer documentable_id documentable_type enabled created_at updated_at])
    documents.find_each { |document| attach_original(document.attached_file, "knowledge/originals/#{document.id}/original") }
  end

  def original_metadata(file, path)
    return {} unless file&.attached?

    { filename: file.filename.to_s, content_type: file.blob.content_type, archive_path: path }
  end

  def attach_original(attachment, path)
    return unless attachment&.attached?

    attachment.blob.open do |file|
      @tar.add_file_simple(path, 0o600, file.size) { |entry| IO.copy_stream(file, entry) }
    end
  end

  def native_knowledge
    client = AiAgents::KnowledgeClient.new(account: @account, actor: @export.user)
    response = client.request(method: :get, path: '/v1/knowledge/bases', action: 'knowledge:read')
    raise 'Knowledge export unavailable' unless response.code == 200

    # The native library contains authored knowledge only. Shopify datasets live in the separate synchronization service.
    response.parsed_response.each do |base|
      id = base.fetch('id')
      raise 'Invalid knowledge base identifier' unless /\A[0-9a-f-]{36}\z/i.match?(id)

      archive = client.request(method: :get, path: "/v1/knowledge/bases/#{id}/export", action: 'knowledge:read')
      raise 'Knowledge export unavailable' unless archive.code == 200

      add("knowledge/native/#{id}.zip", archive.body)
    end
  end
end
