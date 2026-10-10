class AccountDataExportService
  def initialize(export:, zip:)
    @export = export
    @account = export.account
    @zip = zip
  end

  def perform
    add('Start here.txt', readme)
    add('manifest.json', { schema_version: 2, account_id: @account.id, generated_at: Time.current,
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
    @zip.put_next_entry(name)
    @zip.write(content)
  end

  def csv_records(name, records, fields)
    @zip.put_next_entry(name)
    @zip.write("\uFEFF")
    csv = CSVSafe.new(@zip)
    csv << fields.map(&:humanize)
    records.find_each do |record|
      data = record.attributes.slice(*fields)
      data.merge!(yield(record)) if block_given?
      csv << fields.map do |field|
        value = data.key?(field) ? data[field] : data[field.to_sym]
        value.is_a?(Hash) || value.is_a?(Array) ? value.to_json : value
      end
    end
  end

  def readme
    <<~TEXT
      #{@account.name} — #{@export.export_type.humanize} export
      Created: #{Time.current.utc.iso8601} (UTC)

      Open CSV files in Excel, Google Sheets or Numbers. Each file includes column headings.
      Conversations: conversations.csv is the index; messages.csv contains messages and private notes.
      Read individual conversations in the Conversations folder as plain text, in chronological order.
      Match records across spreadsheets using their ID columns.
      Attachments and knowledge originals keep their filenames and extensions.
      Attachment and document spreadsheets include the path to each original file.
      Knowledge: articles, documents and FAQs are spreadsheets. Native knowledge bases are separate ZIP files.
      manifest.json records the export version and scope for technical use.

      Only the selected data is included. Empty spreadsheets have column headings only.
      Shopify product catalog, credentials, assistant instructions and internal strategy are excluded.
      This download is for reading and analysis; it is not an account restore file.
      Conversation exports include private notes. Store and share this export with care.
    TEXT
  end

  def conversations
    csv_records('conversations.csv', @account.conversations.includes(:contact, :inbox),
                %w[id display_id contact_id contact_name inbox_id inbox_name status created_at updated_at transcript_path]) do |conversation|
      { contact_name: conversation.contact.name, inbox_name: conversation.inbox.name,
        transcript_path: "Conversations/conversation-#{conversation.display_id}.txt" }
    end
    csv_records('messages.csv', @account.messages.includes(:sender),
                %w[id conversation_id sender_id sender_type sender_name message_type content private created_at updated_at]) do |message|
      { sender_name: message.sender&.try(:name) }
    end
    transcripts
    attachments
  end

  def transcripts
    @account.conversations.includes(:contact, :inbox).find_each do |conversation|
      @zip.put_next_entry("Conversations/conversation-#{conversation.display_id}.txt")
      @zip.write("Conversation ##{conversation.display_id}\nContact: #{conversation.contact.name}\n")
      @zip.write("Inbox: #{conversation.inbox.name}\nStatus: #{conversation.status}\n\n")
      # Preserve chronological order; find_each would reorder messages by primary key.
      conversation.messages.includes(:sender, attachments: { file_attachment: :blob }).order(:created_at, :id).each do |message|
        transcript_message(message)
      end
    end
  end

  def transcript_message(message)
    sender = message.sender&.try(:name) || message.sender_type || 'System'
    note = message.private? ? ' — Private note' : ''
    @zip.write("[#{message.created_at.iso8601}] #{sender} (#{message.message_type})#{note}\n#{message.content}\n")
    message.attachments.each do |attachment|
      next unless attachment.file.attached?

      @zip.write("Attachment: #{original_path(attachment.file, "attachments/#{attachment.id}")}\n")
    end
    @zip.write("\n")
  end

  def attachments
    records = Attachment.where(account: @account).includes(file_attachment: :blob)
    csv_records('attachments.csv', records,
                %w[id message_id file_type coordinates_lat coordinates_long fallback_title filename content_type archive_path]) do |attachment|
      original_metadata(attachment.file, "attachments/#{attachment.id}")
    end
    records.find_each { |attachment| attach_original(attachment.file, "attachments/#{attachment.id}") }
  end

  def contacts
    csv_records('contacts.csv', @account.contacts,
                %w[id name email phone_number identifier company_name custom_attributes additional_attributes created_at updated_at])
  end

  def knowledge
    csv_records('knowledge/articles.csv', @account.articles, %w[id portal_id category_id title slug content status created_at updated_at])
    captain_knowledge if ChatwootApp.enterprise?
    native_knowledge if @account.feature_enabled?('native_ai_knowledge')
  end

  def captain_knowledge
    documents = Captain::Document.where(account: @account, agents_only: false)
    csv_records('knowledge/documents.csv', documents,
                %w[id assistant_id name content external_link enabled created_at updated_at filename content_type archive_path]) do |document|
      original_metadata(document_original(document), "knowledge/originals/#{document.id}")
    end
    csv_records('knowledge/faqs.csv', Captain::AssistantResponse.where(account: @account, agents_only: false).where(
                                        "documentable_type IS DISTINCT FROM 'Captain::Document' OR documentable_id IN (?)", documents.select(:id)
                                      ), %w[id assistant_id question answer documentable_id documentable_type enabled created_at updated_at])
    documents.find_each { |document| attach_original(document_original(document), "knowledge/originals/#{document.id}") }
  end

  def document_original(document)
    document.pdf_file.attached? ? document.pdf_file : document.markdown_file
  end

  def original_path(file, directory)
    "#{directory}/#{file.filename.to_s.gsub(%r{[\\/\x00-\x1f]}, '_')}"
  end

  def original_metadata(file, path)
    return {} unless file&.attached?

    { filename: file.filename.to_s, content_type: file.blob.content_type, archive_path: original_path(file, path) }
  end

  def attach_original(attachment, path)
    return unless attachment&.attached?

    attachment.blob.open do |file|
      @zip.put_next_entry(original_path(attachment, path))
      IO.copy_stream(file, @zip)
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

      name = base.fetch('name').parameterize.presence || 'knowledge-base'
      add("knowledge/native/#{name}-#{id}.zip", archive.body)
    end
  end
end
