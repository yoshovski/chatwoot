# Telnyx signs every webhook (messaging and TeXML) with Ed25519 over "#{timestamp}|#{raw_body}".
# The public key from Mission Control → Keys & Credentials is a base64-encoded raw 32-byte key.
module Telnyx::WebhookSignature
  # DER SubjectPublicKeyInfo prefix for an Ed25519 key, so OpenSSL can load the raw key bytes.
  ED25519_SPKI_PREFIX = ['302a300506032b6570032100'].pack('H*').freeze
  TOLERANCE = 5.minutes

  module_function

  def valid?(public_key:, signature:, timestamp:, body:)
    return false if [public_key, signature, timestamp].any?(&:blank?)
    return false if (Time.zone.now.to_i - timestamp.to_i).abs > TOLERANCE

    key = OpenSSL::PKey.read(ED25519_SPKI_PREFIX + Base64.decode64(public_key))
    key.verify(nil, Base64.decode64(signature), "#{timestamp}|#{body}")
  rescue OpenSSL::PKey::PKeyError, ArgumentError
    false
  end

  # Signatures are only enforced once the inbox has a public key configured.
  def verify_request!(channel, request)
    public_key = channel.provider_config['public_key']
    return true if public_key.blank?

    valid?(
      public_key: public_key,
      signature: request.headers['telnyx-signature-ed25519'],
      timestamp: request.headers['telnyx-timestamp'],
      body: request.raw_post
    )
  end
end
