require 'zlib'
require 'stringio'

# Discovery requests: one connection pace per origin, SSRF-safe, size-capped and gzip-aware.
class Captain::Websites::PoliteFetcher
  MAX_BYTES = 5.megabytes

  attr_reader :errors

  def initialize(deadline)
    @deadline = deadline
    @last_requests = {}
    @errors = 0
  end

  def before_deadline?
    Process.clock_gettime(Process::CLOCK_MONOTONIC) < @deadline
  end

  # Returns [body, content_type] for a 200 response, nil otherwise.
  def fetch(url, delay)
    pace(url, delay) do
      status, text, content_type = read(url)
      [text, content_type] if status == 200
    end
  end

  # Returns [status, body, content_type] like #read, paced per origin; nil past the deadline.
  def read_paced(url, delay)
    pace(url, delay) { read(url) }
  end

  # The final HTTP status of a page without reading its body; nil when the request failed.
  def probe(url, delay)
    pace(url, delay) do
      SafeFetch.probe(url, read_timeout: 10, headers: { 'User-Agent' => "#{Captain::Websites::RobotsPolicy::AGENT}/1.0" })&.status
    rescue SafeFetch::Error
      @errors += 1
      nil
    end
  end

  # Returns [status, body, content_type]; status is nil when the request itself failed.
  def read(url)
    body, content_type = SafeFetch.fetch(url, validate_content_type: false, max_bytes: MAX_BYTES, read_timeout: 10,
                                              headers: { 'User-Agent' => "#{Captain::Websites::RobotsPolicy::AGENT}/1.0" }) do |result|
      [result.tempfile.read, result.content_type]
    end
    [200, decompress(body), content_type]
  rescue SafeFetch::HttpError => e
    @errors += 1
    [e.message.to_i, nil]
  rescue SafeFetch::Error
    @errors += 1
    [nil, nil]
  end

  private

  # One request per origin at a time, at least `delay` seconds apart.
  def pace(url, delay)
    origin = URI.join(url, '/').to_s.delete_suffix('/')
    wait = delay - (Process.clock_gettime(Process::CLOCK_MONOTONIC) - @last_requests.fetch(origin, 0))
    sleep(wait) if wait.positive?
    return unless before_deadline?

    result = yield
    @last_requests[origin] = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result
  end

  def decompress(body)
    return body unless body.start_with?("\x1F\x8B".b)

    text = Zlib::GzipReader.wrap(StringIO.new(body)) { |reader| reader.read(MAX_BYTES + 1) }
    raise SafeFetch::FileTooLargeError if text.bytesize > MAX_BYTES

    text
  rescue Zlib::Error
    raise SafeFetch::FetchError
  end
end
