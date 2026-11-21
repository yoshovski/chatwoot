require 'date'
require 'json'
require 'optparse'
require 'yaml'

# Compare the catalogs the app loads. Keep counts for missing values and
# suspicious English copies separate, since product names can be identical.
class LocalizationAudit
  ROOT = File.expand_path('..', __dir__)
  JAVASCRIPT = File.join(ROOT, 'app/javascript')
  IMPORT = %r{from ['"]\./([^'"]+\.json)['"]}
  PLACEHOLDER = /%<[[:word:]]+>\w|%?\{[[:word:]]+\}|\{'[^']+'\}|@[.:][[:word:].-]+/

  def initialize
    @dashboard_root = File.join(JAVASCRIPT, 'dashboard/i18n/locale')
  end

  def languages
    File.read(File.join(ROOT, 'config/initializers/languages.rb'))
        .scan(/iso_639_1_code: '([^']+)', enabled: true/).flatten - ['en']
  end

  def catalogs(locale)
    {
      dashboard: dashboard(locale),
      widget: json_catalog('widget', locale),
      survey: json_catalog('survey', locale),
      rails: rails(locale)
    }
  end

  def compare(source, translation, prefix: nil)
    source = source.select { |key, _| key.start_with?(prefix) } if prefix
    result = { keys: source.size, missing: [], conflicting_placeholders: [], same_as_english: [] }
    source.each do |key, value|
      issue = classify(value, translation[key])
      result[issue] << key if issue
    end
    result
  end

  private

  def classify(source, localized)
    return :missing if localized.nil?
    return unless source.is_a?(String) && localized.is_a?(String)
    return :conflicting_placeholders if placeholders(source) != placeholders(localized)
    return :same_as_english if source == localized
  end

  def flatten(messages, path = '', result = {})
    messages.each do |key, value|
      child_path = path.empty? ? key.to_s : "#{path}.#{key}"
      if value.is_a?(Hash)
        flatten(value, child_path, result)
      elsif !value.nil? && (!value.is_a?(String) || !value.strip.empty?)
        result[child_path] = value
      end
    end
    result
  end

  def json_catalog(surface, locale)
    path = File.join(JAVASCRIPT, surface, 'i18n/locale', "#{locale}.json")
    flatten(File.exist?(path) ? JSON.parse(File.read(path)) : {})
  end

  def dashboard(locale)
    directory = File.join(@dashboard_root, locale)
    index = File.join(directory, 'index.js')
    return {} unless File.exist?(index)

    messages = File.read(index).scan(IMPORT).flatten.reduce({}) do |result, file|
      result.merge(JSON.parse(File.read(File.join(directory, file))))
    end
    flatten(messages)
  end

  def rails(locale)
    files = Dir[File.join(ROOT, 'config/locales', '*.yml')].select { |file| file.end_with?("/#{locale}.yml", ".#{locale}.yml") }
    files.each_with_object({}) do |file, result|
      value = YAML.safe_load(File.read(file), permitted_classes: [Date, Time, Symbol], aliases: true)
      result.merge!(flatten((value || {}).fetch(locale, {})))
    end
  end

  def placeholders(text)
    text.scan(PLACEHOLDER).uniq.sort
  end
end

if $PROGRAM_NAME == __FILE__
  options = { details: false }
  OptionParser.new do |parser|
    parser.on('--locales LOCALES', Array) { |locales| options[:locales] = locales }
    parser.on('--dashboard-prefix PREFIX') { |prefix| options[:prefix] = prefix }
    parser.on('--details') { options[:details] = true }
    parser.on('--strict') { options[:strict] = true }
  end.parse!
  audit = LocalizationAudit.new
  source = audit.catalogs('en')
  source = source.slice(:dashboard) if options[:prefix]
  failed = false
  results = (options[:locales] || audit.languages).to_h do |locale|
    translation = audit.catalogs(locale)
    counts = source.to_h do |surface, messages|
      result = audit.compare(messages, translation.fetch(surface), prefix: options[:prefix])
      failed ||= result[:missing].any? || result[:conflicting_placeholders].any?
      result.transform_values! { |value| value.is_a?(Array) ? value.size : value } unless options[:details]
      [surface, result]
    end
    [locale, counts]
  end
  puts JSON.pretty_generate(results)
  exit 1 if options[:strict] && failed
end
