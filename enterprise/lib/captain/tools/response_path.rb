require 'strscan'

# Reads one value out of a parsed response with a short path: `order.email`, `items[0].sku`, `items[*].sku` (an array
# of every item's value) and `meta["x.y"]` for keys that hold dots. A path that doesn't match the data gives nil.
class Captain::Tools::ResponsePath
  ALL = :all

  def self.parse(path)
    scanner = StringScanner.new(path.to_s.strip)
    tokens = []
    until scanner.eos?
      token = next_token(scanner, first: tokens.empty?)
      return nil if token.nil?

      tokens << token
    end
    tokens.presence
  end

  def self.valid?(path) = parse(path).present?

  def self.dig(data, path)
    tokens = parse(path)
    tokens ? walk(data, tokens) : nil
  end

  def self.next_token(scanner, first:)
    if scanner.scan('[*]') then ALL
    elsif scanner.scan(/\[(\d+)\]/) then scanner[1].to_i
    elsif scanner.scan(/\["((?:[^"\\]|\\.)*)"\]/) then scanner[1].gsub(/\\(.)/, '\1')
    elsif scanner.scan(first ? /([^.\[\]"]+)/ : /\.([^.\[\]"]+)/) then scanner[1]
    end
  end

  def self.walk(value, tokens)
    return value if tokens.empty?

    token, *rest = tokens
    return value.map { |item| walk(item, rest) } if token == ALL && value.is_a?(Array)

    child = step_into(value, token)
    child.nil? ? nil : walk(child, rest)
  end

  # The value under one key or index, or nil when the token doesn't fit the value (a key on an array, say).
  def self.step_into(value, token)
    case token
    when String then value[token] if value.is_a?(Hash)
    when Integer then value[token] if value.is_a?(Array)
    end
  end

  private_class_method :next_token, :walk, :step_into
end
