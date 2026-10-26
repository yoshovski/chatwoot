# The setup screen and delivery job use the same checks; no message is sent here.
class Captain::Leads::NotificationReadiness
  ERRORS = {
    'missing_team' => 'Select an existing lead notification team',
    'email_unavailable' => 'Configure SMTP before enabling lead notifications',
    'empty_team' => 'Add a member to the lead notification team',
    'rate_limited' => 'The account email limit has been reached'
  }.freeze

  def self.status(account, team)
    return 'missing_team' unless team
    return 'email_unavailable' unless ENV['SMTP_ADDRESS'].present? || Rails.env.development?
    return 'empty_team' unless team.team_members.exists?
    return 'rate_limited' unless account.within_email_rate_limit?

    'ready'
  end

  def self.validate!(account, team)
    status = status(account, team)
    raise ERRORS.fetch(status) unless status == 'ready'
  end
end
