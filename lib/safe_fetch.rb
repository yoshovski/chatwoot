require 'ssrf_filter'

module SafeFetch
  DEFAULT_ALLOWED_CONTENT_TYPE_PREFIXES = %w[image/ video/].freeze
  DEFAULT_ALLOWED_CONTENT_TYPES = [].freeze
  DEFAULT_SENSITIVE_HEADERS = %w[authorization cookie proxy-authorization].freeze
  DEFAULT_OPEN_TIMEOUT = 2
  DEFAULT_READ_TIMEOUT = 20
  DEFAULT_MAX_BYTES_FALLBACK_MB = 40

  Result = Data.define(:tempfile, :filename, :content_type) do
    def original_filename
      filename
    end
  end

  Probe = Data.define(:status, :headers)

  class Error < StandardError; end
  class InvalidUrlError < Error; end
  class UnsafeUrlError < Error; end
  class FetchError < Error; end
  class HttpError < Error; end
  class FileTooLargeError < Error; end
  class UnsupportedContentTypeError < Error; end
  class UnsupportedMethodError < Error; end

  def self.fetch(url, **, &)
    raise ArgumentError, 'block required' unless block_given?

    translate_errors { SafeFetch::Fetcher.new(SafeFetch::RequestOptions.new(url: url, **)).fetch(&) }
  end

  # Requests the final URL (following redirects) and returns its status and lowercase response headers
  # without reading the body, so a 304 is an answer rather than an error.
  def self.probe(url, **)
    translate_errors { SafeFetch::Fetcher.new(SafeFetch::RequestOptions.new(url: url, **)).probe }
  end

  def self.translate_errors
    yield
  rescue SsrfFilter::InvalidUriScheme, URI::InvalidURIError => e
    raise InvalidUrlError, e.message
  rescue SsrfFilter::Error, Resolv::ResolvError => e
    raise UnsafeUrlError, e.message
  end
  private_class_method :translate_errors

  def self.allow_private_network?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch('SAFE_FETCH_ALLOW_PRIVATE_NETWORK', false))
  end
end
