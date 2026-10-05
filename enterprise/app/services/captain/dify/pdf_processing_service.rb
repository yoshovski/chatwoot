module Captain::Dify::PdfProcessingService
  def initialize(document)
    @document = document
  end

  def process
    Captain::Dify::SyncDocumentJob.perform_later(@document.id)
  end
end
