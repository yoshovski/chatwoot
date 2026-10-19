class Api::V1::Accounts::Captain::WebsiteSourcesController < Api::V1::Accounts::BaseController
  before_action -> { authorize(Captain::Assistant, :update?) }
  before_action :set_assistant
  before_action :set_source, only: %i[show update rediscover preview]

  def index
    render json: @assistant.website_sources.order(created_at: :desc).map do |source|
      source.as_json(only: %i[id url status selected_urls discovery_stats error_code discovered_at])
    end
  end

  def show
    render json: @source.client_payload
  end

  def create
    permitted = params.require(:website_source).permit(:url, :include_subdomains)
    if permitted.key?(:include_subdomains) && [true, false].exclude?(permitted[:include_subdomains])
      return render json: { error: I18n.t('captain.websites.invalid_subdomain_option') }, status: :unprocessable_entity
    end

    @source = @assistant.website_sources.create!(permitted)
    Captain::Websites::DiscoverJob.perform_later(@source.id)
    render json: @source.client_payload, status: :accepted
  rescue ActiveRecord::RecordNotUnique
    render json: { error: I18n.t('captain.websites.already_added') }, status: :unprocessable_entity
  end

  def update
    Captain::Websites::SelectionService.new(@source).perform(params.require(:website_source)[:selected_urls])
    render json: @source.client_payload
  rescue Captain::Websites::SelectionService::InvalidSelection, Captain::Document::LimitExceededError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def rediscover
    @source.with_lock do
      return head :conflict if @source.status.in?(%w[pending discovering]) && @source.updated_at > 2.hours.ago

      @source.update!(status: 'pending', error_code: nil)
      Captain::Websites::DiscoverJob.perform_later(@source.id)
    end
    render json: @source.client_payload, status: :accepted
  end

  def preview
    url = params.require(:url)
    return head :unprocessable_entity unless @source.selectable_urls.include?(url)

    document = @assistant.documents.find_by(external_link: url)
    if document&.content.present?
      render json: { title: document.name, content: document.content.first(20_000) }
      return
    end
    result = Captain::Websites::PageFetcher.new(@source).fetch(url)
    render json: { title: result.title, content: result.content.to_s.first(20_000), error_code: result.error_code },
           status: result.success ? :ok : :unprocessable_entity
  end

  private

  def set_assistant
    @assistant = Current.account.captain_assistants.find(params[:assistant_id])
  end

  def set_source
    @source = @assistant.website_sources.find(params[:id])
  end
end
