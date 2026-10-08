class Captain::Documents::ResponseBuilderJob < ApplicationJob
  queue_as :low

  def perform(document, options = {})
    options = options.with_indifferent_access

    if document.pdf_document?
      perform_for_pdf(document, options)
    else
      perform_for_website(document, options)
    end
  end

  private

  def perform_for_pdf(document, options)
    reset_previous_pdf_responses(document)
    faqs = generate_pdf_faqs(document, options)
    create_responses(faqs, document, origin: 'ai_generated')
  end

  def perform_for_website(document, options)
    import_page_faqs(document) if page_faqs_present?(document)
    generate_ai_faqs(document) if should_generate_ai_faqs?(document, options)
  end

  def page_faqs_present?(document)
    document.metadata.is_a?(Hash) && document.metadata['page_faqs'].present?
  end

  def import_page_faqs(document)
    document.responses.where(origin: 'page_import', edited: false).destroy_all
    document.metadata['page_faqs'].each do |faq|
      create_response(faq, document, origin: 'page_import')
    end
  end

  def should_generate_ai_faqs?(document, options)
    !document.account.dify_knowledge_enabled? || options[:force_ai] == true
  end

  def generate_ai_faqs(document)
    document.responses.where(origin: ['ai_generated', nil], edited: false).destroy_all
    faqs = Captain::Llm::FaqGeneratorService.new(document: document).generate
    create_responses(faqs, document, origin: 'ai_generated')
  end

  def reset_previous_pdf_responses(document)
    document.responses.where(edited: false).destroy_all
  end

  def generate_pdf_faqs(document, options)
    if should_use_pagination?(document)
      generate_paginated_faqs(document, options)
    else
      generate_standard_faqs(document)
    end
  end

  def generate_paginated_faqs(document, options)
    service = build_paginated_service(document, options)
    faqs = service.generate
    store_paginated_metadata(document, service)
    faqs
  end

  def generate_standard_faqs(document)
    Captain::Llm::FaqGeneratorService.new(document: document).generate
  end

  def build_paginated_service(document, options)
    Captain::Llm::PaginatedFaqGeneratorService.new(
      document,
      pages_per_chunk: options[:pages_per_chunk],
      max_pages: options[:max_pages],
      language: document.account.locale_english_name
    )
  end

  def store_paginated_metadata(document, service)
    document.update!(
      metadata: (document.metadata || {}).merge(
        'faq_generation' => {
          'method' => 'paginated',
          'pages_processed' => service.total_pages_processed,
          'iterations' => service.iterations_completed,
          'timestamp' => Time.current.iso8601
        }
      )
    )
  end

  def create_responses(faqs, document, origin:)
    Array(faqs).each { |faq| create_response(faq, document, origin: origin) }
  end

  def create_response(faq, document, origin:)
    question = faq['question'] || faq[:question]
    answer = faq['answer'] || faq[:answer]
    return if question.blank? || answer.blank?

    document.responses.create!(
      question: question,
      answer: answer,
      origin: origin,
      assistant: document.assistant,
      documentable: document
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error I18n.t('captain.documents.response_creation_error', error: e.message)
  end

  def should_use_pagination?(document)
    document.pdf_document? && document.openai_file_id.present?
  end
end
