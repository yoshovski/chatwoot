# Name and description of an AI agent's Dify datasets, so the Dify Knowledge list shows which account and agent
# each one belongs to. The account (tenant) id leads the name and survives renames; names refresh on rename.
class Captain::Dify::DatasetIdentity
  # Dify rejects dataset names over 40 characters.
  MAX_NAME_LENGTH = 40
  KINDS = %w[faq docs].freeze

  def initialize(assistant)
    @assistant = assistant
    @account = assistant.account
  end

  def attributes(kind)
    I18n.with_locale(@account.locale) do
      label = I18n.t("captain.dify_datasets.#{kind}.label")
      { name: name(label), description: I18n.t("captain.dify_datasets.#{kind}.description", **description_values) }
    end
  end

  private

  def name(label)
    prefix = "##{@account.id} "
    suffix = " · #{label}"
    names = [@account.name, agent_name].compact_blank.join(' · ')
    "#{prefix}#{names.truncate(MAX_NAME_LENGTH - prefix.length - suffix.length, omission: '…')}#{suffix}"
  end

  # An agent named like its account adds nothing to the name.
  def agent_name
    @assistant.name unless @assistant.name.to_s.casecmp?(@account.name.to_s)
  end

  def description_values
    { agent: @assistant.name, account: @account.name, account_id: @account.id, agent_id: @assistant.id }
  end
end
