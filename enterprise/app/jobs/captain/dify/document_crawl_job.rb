module Captain::Dify::DocumentCrawlJob
  private

  def perform_pdf_processing(document)
    Captain::Llm::PdfProcessingService.new(document).process
  end
end
