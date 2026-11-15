# The public agent preview (T27) lives in Redis only: a preview expires after 7 days and the instant-agent result of a
# website is reused for 24 hours, so nothing has to clean up after visitors and no table holds their addresses.
# A preview is { url, domain, profile, pages, history, claimed_at }; its token is the only way to reach it.
class Captain::AgentPreviews::Store
  PREVIEW_TTL = 7.days
  DOMAIN_TTL = 24.hours
  MAX_HISTORY = 6

  class << self
    def create(url:, domain:, result:)
      token = SecureRandom.urlsafe_base64(24)
      write(token, { 'url' => url, 'domain' => domain, 'profile' => result[:profile], 'pages' => result[:pages],
                     'history' => [], 'created_at' => Time.current.iso8601 })
      token
    end

    def find(token)
      return if token.blank? || !token.to_s.match?(/\A[\w-]{20,64}\z/)

      raw = Redis::Alfred.get(key(token))
      raw && JSON.parse(raw)
    end

    # Keeps the preview's remaining lifetime; only the last few turns are kept for the model.
    def update(token, preview)
      ttl = Redis::Alfred.ttl(key(token)).to_i
      return if ttl <= 0

      preview['history'] = preview['history'].last(MAX_HISTORY)
      Redis::Alfred.set(key(token), preview.to_json, ex: ttl)
    end

    # The first claim wins; a second claim of the same preview gets false.
    def claim!(token)
      Redis::Alfred.set("#{key(token)}:claimed", Time.current.iso8601, nx: true, ex: PREVIEW_TTL.to_i)
    end

    # A claim that failed (the email already has an account) frees the preview for another try.
    def release!(token)
      Redis::Alfred.delete("#{key(token)}:claimed")
    end

    def cached_result(domain)
      raw = Redis::Alfred.get(domain_key(domain))
      raw && JSON.parse(raw).deep_symbolize_keys
    end

    def cache_result(domain, result)
      Redis::Alfred.set(domain_key(domain), result.to_json, ex: DOMAIN_TTL.to_i)
    end

    private

    def write(token, preview) = Redis::Alfred.set(key(token), preview.to_json, ex: PREVIEW_TTL.to_i)

    def key(token) = "agent_preview:#{token}"

    def domain_key(domain) = "agent_preview:domain:#{domain}"
  end
end
