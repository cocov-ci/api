# frozen_string_literal: true

module Cocov
  module Crypto
    class NoCryptographicKey < StandardError; end

    module_function

    IV_ALGO = "aes-128-cbc"
    IV_SIZE = 16
    CRYPTO_ALGO = "aes-256-cbc"

    def ensure_key!
      return if CRYPTOGRAPHIC_KEY.present?

      raise NoCryptographicKey, "Cannot use Cocov::Crypto without a cryptographic key set"
    end

    def make_iv
      cipher = OpenSSL::Cipher::Cipher.new(IV_ALGO)
      cipher.encrypt
      cipher.random_iv
    end

    def encrypt(data)
      ensure_key!
      cipher = OpenSSL::Cipher::Cipher.new(CRYPTO_ALGO)
      cipher.encrypt
      cipher.key = CRYPTOGRAPHIC_KEY
      iv = make_iv
      cipher.iv = iv
      result = "#{cipher.update(data.encode("utf-8"))}#{cipher.final}"
      [[IV_SIZE.to_s(16)].pack("H*"), iv, result].join
    end

    def decrypt(data)
      ensure_key!
      iv_size = data[0].unpack1("C*")
      iv = data[1..iv_size]
      encoded = data[iv_size + 1..]

      cipher = OpenSSL::Cipher::Cipher.new(CRYPTO_ALGO)
      cipher.decrypt
      cipher.key = CRYPTOGRAPHIC_KEY
      cipher.iv = iv
      "#{cipher.update(encoded)}#{cipher.final}".force_encoding("utf-8")
    end
  end
end
