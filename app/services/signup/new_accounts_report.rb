# Super Admin "New accounts" (T11): the latest public signups with flags that suggest one person taking several trials.
class Signup::NewAccountsReport
  PER_PAGE = 50
  SAME_IP_WINDOW = 30.days

  Row = Struct.new(:signup, :flags, keyword_init: true)

  def initialize(page: 1, flagged_only: false)
    @page = [page.to_i, 1].max
    @flagged_only = flagged_only
  end

  def rows
    @rows ||= begin
      signups = AccountSignup.includes(:account, :user).order(created_at: :desc, id: :desc)
      # Flags are worked out per page; "flagged only" looks at the last 500 signups.
      signups = @flagged_only ? signups.limit(500) : signups.offset((@page - 1) * PER_PAGE).limit(PER_PAGE + 1)
      built = with_flags(signups.to_a)
      @flagged_only ? built.select { |row| row.flags.any? }.first(PER_PAGE) : built
    end
  end

  def next_page?
    !@flagged_only && rows.size > PER_PAGE
  end

  def visible_rows
    rows.first(PER_PAGE)
  end

  private

  def with_flags(signups)
    domain_counts = count_domains(signups.flat_map(&:trial_domains).uniq)
    ip_counts = count_ips(signups.filter_map(&:ip).uniq)

    signups.map do |signup|
      flags = {
        'same_domain' => signup.trial_domains.any? { |domain| domain_counts[domain].to_i > 1 },
        'same_ip' => ip_counts[signup.ip].to_i > 1,
        'disposable_looking' => disposable_looking?(signup.email)
      }
      Row.new(signup: signup, flags: flags.select { |_flag, on| on }.keys)
    end
  end

  # How many signups (deleted accounts included) share each domain.
  def count_domains(domains)
    return {} if domains.empty?

    email = AccountSignup.where(email_domain: domains).group(:email_domain).count
    website = AccountSignup.where(website_domain: domains).where('website_domain IS DISTINCT FROM email_domain').group(:website_domain).count
    email.merge(website) { |_domain, a, b| a + b }
  end

  def count_ips(ips)
    return {} if ips.empty?

    AccountSignup.where(ip: ips, created_at: SAME_IP_WINDOW.ago..).group(:ip).count
  end

  # A throwaway address: a known disposable domain, a +tag, or a run of digits in the name (anna83920@…).
  def disposable_looking?(email)
    return false if email.blank?

    address = ValidEmail2::Address.new(email)
    address.disposable? || address.subaddressed? || email.split('@').first.match?(/\d{4,}/)
  end
end
