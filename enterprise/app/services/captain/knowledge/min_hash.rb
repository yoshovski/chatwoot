# Compact MinHash of a text's word 3-shingles: 32 values, stored as one 256-character hex string.
# The share of equal values estimates how much text two pages share, so a mirror with another
# footer, date or banner is caught while pages that only share a banner are not.
module Captain::Knowledge::MinHash
  SIZE = 32
  PRIME = (1 << 61) - 1
  SEEDS = Array.new(SIZE) { |index| [((2 * index) + 1) * 0x9E3779B97F4A7C15 % PRIME, (index + 1) * 0xC2B2AE3D27D4EB4F % PRIME] }.freeze
  # Measured on real copies (0.81–1.0) and on different pages sharing a banner (at most 0.56).
  NEAR = 0.75
  # Pages sharing one band of four values are compared; near copies almost always share one.
  BAND = 4

  def self.of(text)
    shingles = text.to_s.downcase.scan(/[[:alnum:]]+/).each_cons(3).map { |words| Digest::MD5.digest(words.join(' ')).unpack1('Q>') % PRIME }
    return if shingles.empty?

    shingles.uniq!
    SEEDS.map { |a, b| (shingles.map { |value| ((a * value) + b) % PRIME }.min & 0xFFFFFFFF).to_s(16).rjust(8, '0') }.join
  end

  def self.similarity(first, second)
    first.scan(/.{8}/).zip(second.scan(/.{8}/)).count { |left, right| left == right }.fdiv(SIZE)
  end

  def self.near?(first, second) = first.present? && second.present? && similarity(first, second) >= NEAR

  def self.bands(signature) = signature.scan(/.{#{8 * BAND}}/).each_with_index.map { |band, index| "#{index}:#{band}" }

  # Remembers signatures by band, so a new one is only compared with signatures sharing a band.
  class Index
    def initialize
      @bands = Hash.new { |bands, band| bands[band] = [] }
    end

    def near?(signature)
      candidates = Captain::Knowledge::MinHash.bands(signature).flat_map { |band| @bands[band] }
      candidates.any? { |other| Captain::Knowledge::MinHash.near?(other, signature) }
    end

    def add(signature) = Captain::Knowledge::MinHash.bands(signature).each { |band| @bands[band] << signature }
  end
end
