require 'digest'

# A YAML file of invented conversations and the checks their replies must pass. See README.md for the format.
class Captain::Evals::Suite
  DIRECTORY = Rails.root.join('enterprise/lib/captain/evals/suites')
  CASE_KEYS = %w[id title settings message history channel campaign routing locale contact_name scenarios expect].freeze

  class Invalid < StandardError; end

  attr_reader :name, :data

  def self.load(name_or_path)
    path = File.exist?(name_or_path.to_s) ? Pathname.new(name_or_path) : DIRECTORY.join("#{name_or_path}.yml")
    raise Invalid, "Suite not found: #{name_or_path}" unless path.exist?

    new(path.basename('.yml').to_s, YAML.safe_load_file(path))
  end

  def initialize(name, data)
    @name = name
    @data = data
    validate!
  end

  def business = data.fetch('business')

  def knowledge = business.fetch('knowledge', [])

  # Assistant settings every case starts from; a case's settings override them.
  def defaults = data.fetch('defaults', {})

  def cases(only: nil)
    selected = data.fetch('cases')
    only.present? ? selected.select { |test_case| only.include?(test_case['id']) } : selected
  end

  # The case's checks, with its expected route as one more check.
  def checks_for(test_case)
    route = test_case.dig('expect', 'route')
    Array(test_case.dig('expect', 'checks')) + (route ? [{ 'route' => route }] : [])
  end

  # Stable across key order and formatting, so a report names exactly which suite produced it.
  def sha256 = Digest::SHA256.hexdigest(canonical(data).to_json)

  private

  def canonical(value)
    case value
    when Hash then value.keys.sort.index_with { |key| canonical(value[key]) }
    when Array then value.map { |item| canonical(item) }
    else value
    end
  end

  def validate!
    raise Invalid, 'version must be 1' unless data.is_a?(Hash) && data['version'] == 1

    validate_business!
    ids = data.fetch('cases').map { |test_case| validate_case!(test_case) }
    raise Invalid, 'case ids must be unique' unless ids.uniq.size == ids.size
  end

  def validate_business!
    raise Invalid, 'business needs name and description' unless business.is_a?(Hash) && business.values_at('name', 'description').all?(&:present?)
    return if knowledge.all? { |entry| entry.values_at('title', 'url', 'content').all?(&:present?) }

    raise Invalid, 'knowledge entries need title, url and content'
  end

  def validate_case!(test_case)
    id = test_case['id']
    raise Invalid, 'every case needs id, title and message' unless id.present? && test_case['title'].present? && test_case['message'].present?

    unknown = test_case.keys - CASE_KEYS
    raise Invalid, "#{id}: unknown keys #{unknown.join(', ')}" if unknown.any?

    checks = checks_for(test_case)
    raise Invalid, "#{id}: expect.checks is empty" if checks.empty?

    checks.each { |check| validate_check!(id, check) }
    id
  end

  def validate_check!(id, check)
    name = check.is_a?(Hash) ? check.keys.first.to_s : check.to_s
    raise Invalid, "#{id}: unknown check #{name}" unless Captain::Evals::Checks::NAMES.include?(name)
    raise Invalid, "#{id}: #{name} takes one argument" if check.is_a?(Hash) && check.size != 1

    validate_any_of!(id, check.is_a?(Hash) ? check.values.first : nil) if name == 'any_of'
  end

  def validate_any_of!(id, options)
    raise Invalid, "#{id}: any_of takes a list of checks" unless options.is_a?(Array) && options.any?

    options.each { |option| validate_check!(id, option) }
  end
end
