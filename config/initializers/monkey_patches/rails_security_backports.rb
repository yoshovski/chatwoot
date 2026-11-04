# Backports of Rails security fixes that have no Rails 7.2 release.
#
# Rails shipped these fixes only in 8.0.5.2 and 8.1.4.1 (2026-11-04). Each patch
# copies the upstream 8.0 change. They switch themselves off once the app runs a
# fixed Rails, so delete this file as part of the Rails 8 upgrade, together with
# the matching ignores in .bundler-audit.yml.
if ActiveSupport.gem_version < Gem::Version.new('8.0.5.2')
  # GHSA-8474-xrp6-wh69 (rails/rails@210ac22d). safe_constantize built a Regexp
  # from the requested constant name when lookup raised LoadError. Action Cable
  # passes the `channel` of every subscribe command here, and our /cable endpoint
  # accepts anonymous widget visitors, so the name is attacker controlled.
  # Match the first name segment as a literal string instead.
  module ActiveSupport::Inflector
    # Same body as Rails 8.0.5.2, kept verbatim so it is easy to compare.
    def safe_constantize(camel_cased_word) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      constantize(camel_cased_word)
    rescue NameError => e
      raise if e.name && !(camel_cased_word.to_s.split('::').include?(e.name.to_s) ||
        e.name.to_s == camel_cased_word.to_s)
    rescue LoadError => e
      message = e.respond_to?(:original_message) ? e.original_message : e.message
      constant_name = camel_cased_word.split('::').find { |part| !part.empty? } || camel_cased_word
      raise unless message.include?("Unable to autoload constant #{constant_name}")
    end
  end

  # GHSA-wm3x-v3qw-4jh3 (rails/rails@2fc88383). Parameters#each_key delegated to
  # the raw hash, so with a block it returned an unpermitted hash that mass
  # assignment accepts. Return the Parameters instance, as each_pair does.
  module ParametersEachKeyBackport
    def each_key(&)
      return to_enum(:each_key) unless block_given?

      @parameters.each_key(&)

      self
    end
  end

  ActionController::Parameters.prepend(ParametersEachKeyBackport)
end
