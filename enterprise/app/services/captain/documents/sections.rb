# Groups an agent's documents like website discovery groups pages: by host and first path segment.
# Uploaded files and documents without a web address form one group.
class Captain::Documents::Sections
  FILES = 'files'.freeze
  STATES = %w[ready syncing failed paused].freeze

  def self.key_for(external_link)
    uri = URI.parse(external_link.to_s)
    uri.is_a?(URI::HTTP) && uri.host.present? ? Captain::Websites::PageRules.section(uri.to_s) : FILES
  rescue URI::InvalidURIError
    FILES
  end

  def initialize(assistant)
    @assistant = assistant
  end

  # Largest sections first, files last; each with a count per state.
  def groups
    groups = rows.group_by(&:first).map do |key, items|
      states = items.map(&:second).tally
      { key: key, count: items.size, **STATES.index_with { |state| states.fetch(state, 0) }.symbolize_keys }
    end
    groups.sort_by { |group| [group[:key] == FILES ? 1 : 0, -group[:count], group[:key]] }
  end

  def documents(keys)
    @assistant.documents.where(id: rows.filter_map { |key, _, id| id if keys.include?(key) })
  end

  private

  def rows
    @rows ||= @assistant.documents.pluck(:id, :external_link, :enabled, :status, :sync_status).map do |id, link, enabled, status, sync_status|
      [self.class.key_for(link), state(enabled, status, sync_status), id]
    end
  end

  def state(enabled, status, sync_status)
    return 'paused' unless enabled
    return 'failed' if sync_status == 'failed'

    status == 'available' ? 'ready' : 'syncing'
  end
end
