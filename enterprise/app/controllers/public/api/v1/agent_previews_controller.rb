# Public agent preview for chatoctave.com (T27): website address → preview, three messages, email → account.
# Reached only through the site's proxy route, which sends AGENT_PREVIEW_PROXY_KEY and the visitor's IP; without the key
# set the feature is off. The app origin stays hidden and the site's own rate limit runs first.
# Creating and claiming need a captcha (Turnstile) like the sign-up form.
class Public::Api::V1::AgentPreviewsController < PublicController
  PROXY_KEY_HEADER = 'X-Agent-Preview-Key'.freeze
  CLIENT_IP_HEADER = 'X-Agent-Preview-Client-Ip'.freeze
  REFUSALS = {
    invalid_url: :unprocessable_entity, blocked: :unprocessable_entity, invalid_message: :unprocessable_entity,
    invalid_email: :unprocessable_entity, terms_not_accepted: :unprocessable_entity, email_taken: :conflict,
    already_claimed: :conflict, limited: :too_many_requests, no_messages_left: :too_many_requests,
    busy: :service_unavailable, no_reply: :service_unavailable, signup_closed: :forbidden, captcha: :forbidden
  }.freeze

  before_action :ensure_proxy
  before_action :validate_captcha, only: [:create, :claim]
  before_action :set_preview, only: [:messages, :claim]

  def create
    result = Captain::AgentPreviews::CreateService.new(url: params[:url], ip: client_ip).perform
    return render_refusal(result[:status]) unless result[:status] == :ready

    render json: preview_json(result[:token], result[:preview]), status: :created
  end

  def messages
    left = Captain::AgentPreviews::Limits.message_allowed?(params[:token])
    return render_refusal(:no_messages_left) if left.nil?
    return render_refusal(:invalid_message) if params[:content].to_s.strip.blank?

    reply = Captain::AgentPreviews::ChatService.new(@preview, params[:content]).perform
    Captain::AgentPreviews::Store.update(params[:token], @preview)
    render json: { reply: reply, messages_left: left }
  rescue Captain::AgentPreviews::ChatService::NoReply, RubyLLM::Error, Faraday::Error
    render_refusal(:no_reply)
  end

  def claim
    return render_refusal(:signup_closed) unless GlobalConfigService.account_signup_enabled?
    return render_refusal(:terms_not_accepted) unless params[:terms_accepted] == true

    user = Captain::AgentPreviews::ClaimService.new(token: params[:token], preview: @preview, email: params[:email].to_s.strip,
                                                    ip: client_ip, locale: params[:locale]).perform
    render json: { email: user.email }, status: :created
  rescue Captain::AgentPreviews::ClaimService::AlreadyClaimed
    render_refusal(:already_claimed)
  rescue CustomExceptions::Account::UserExists
    render_refusal(:email_taken)
  rescue CustomExceptions::Account::InvalidEmail, CustomExceptions::Account::UserErrors, ActiveRecord::RecordInvalid
    render_refusal(:invalid_email)
  end

  private

  def render_refusal(code)
    render json: { error: code }, status: REFUSALS.fetch(code)
  end

  def ensure_proxy
    key = ENV.fetch('AGENT_PREVIEW_PROXY_KEY', '')
    head :not_found if key.blank? || !ActiveSupport::SecurityUtils.secure_compare(request.headers[PROXY_KEY_HEADER].to_s, key)
  end

  def validate_captcha
    return render_refusal(:captcha) unless ChatwootCaptcha.configured?

    render_refusal(:captcha) unless ChatwootCaptcha.new(params[:captcha_response], remote_ip: client_ip).valid?
  end

  def set_preview
    @preview = Captain::AgentPreviews::Store.find(params[:token])
    head :not_found if @preview.nil?
  end

  # Only the proxy (checked above) can set the visitor's IP; the header is ignored if it is not an IP.
  def client_ip
    @client_ip ||= begin
      IPAddr.new(request.headers[CLIENT_IP_HEADER].to_s).to_s
    rescue IPAddr::Error
      request.remote_ip
    end
  end

  # No page text: the site only shows what the card needs.
  def preview_json(token, preview)
    profile = preview['profile'] || {}
    {
      token: token, url: preview['url'], domain: preview['domain'], pages_read: preview['pages'].size,
      messages_left: Captain::AgentPreviews::Limits.messages_left(token),
      agent: profile.slice('name', 'language', 'brand_color', 'logo_url', 'starter_questions')
    }
  end
end
