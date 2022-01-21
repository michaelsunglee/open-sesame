require "rlp"
require "ffi"
require "openssl"
require 'digest/keccak'
require 'eth'

class VerifySignature
  extend FFI::Library
  ffi_lib FFI::CURRENT_PROCESS
  NID_secp256k1 = 714

  attach_function :OPENSSL_init_ssl, [:uint64, :pointer], :int
  attach_function :BN_CTX_free, [:pointer], :int
  attach_function :BN_CTX_new, [], :pointer
  attach_function :BN_add, %i[pointer pointer pointer], :int
  attach_function :BN_bin2bn, %i[pointer int pointer], :pointer
  attach_function :BN_bn2bin, %i[pointer pointer], :int
  attach_function :BN_cmp, %i[pointer pointer], :int
  attach_function :BN_dup, [:pointer], :pointer
  attach_function :BN_free, [:pointer], :int
  attach_function :BN_mod_inverse, %i[pointer pointer pointer pointer], :pointer
  attach_function :BN_mod_mul, %i[pointer pointer pointer pointer pointer], :int
  attach_function :BN_mod_sub, %i[pointer pointer pointer pointer pointer], :int
  attach_function :BN_mul_word, %i[pointer int], :int
  attach_function :BN_new, [], :pointer
  attach_function :BN_rshift, %i[pointer pointer int], :int
  attach_function :BN_rshift1, %i[pointer pointer], :int
  attach_function :BN_set_word, %i[pointer int], :int
  attach_function :BN_sub, %i[pointer pointer pointer], :int
  attach_function :EC_GROUP_get_curve_GFp, %i[pointer pointer pointer pointer pointer], :int
  attach_function :EC_GROUP_get_degree, [:pointer], :int
  attach_function :EC_GROUP_get_order, %i[pointer pointer pointer], :int
  attach_function :EC_KEY_free, [:pointer], :int
  attach_function :EC_KEY_get0_group, [:pointer], :pointer
  attach_function :EC_KEY_get0_private_key, [:pointer], :pointer
  attach_function :EC_KEY_new_by_curve_name, [:int], :pointer
  attach_function :EC_KEY_set_conv_form, %i[pointer int], :void
  attach_function :EC_KEY_set_private_key, %i[pointer pointer], :int
  attach_function :EC_KEY_set_public_key, %i[pointer pointer], :int
  attach_function :EC_POINT_free, [:pointer], :int
  attach_function :EC_POINT_mul, %i[pointer pointer pointer pointer pointer pointer], :int
  attach_function :EC_POINT_new, [:pointer], :pointer
  attach_function :EC_POINT_set_compressed_coordinates_GFp,
                  %i[pointer pointer pointer int pointer], :int
  attach_function :i2o_ECPublicKey, %i[pointer pointer], :uint
  attach_function :ECDSA_do_sign, %i[pointer uint pointer], :pointer
  attach_function :BN_num_bits, [:pointer], :int
  attach_function :ECDSA_SIG_free, [:pointer], :void
  attach_function :EC_POINT_add, %i[pointer pointer pointer pointer pointer], :int
  attach_function :EC_POINT_point2hex, %i[pointer pointer int pointer], :string
  attach_function :EC_POINT_hex2point, %i[pointer string pointer pointer], :pointer
  attach_function :d2i_ECDSA_SIG, %i[pointer pointer long], :pointer
  attach_function :i2d_ECDSA_SIG, %i[pointer pointer], :int
  attach_function :OPENSSL_free, :CRYPTO_free, [:pointer], :void

  OPENSSL_INIT_LOAD_SSL_STRINGS = 0x00200000
  OPENSSL_INIT_ENGINE_RDRAND = 0x00000200
  OPENSSL_INIT_ENGINE_DYNAMIC = 0x00000400
  OPENSSL_INIT_ENGINE_CRYPTODEV = 0x00001000
  OPENSSL_INIT_ENGINE_CAPI = 0x00002000
  OPENSSL_INIT_ENGINE_PADLOCK = 0x00004000
  OPENSSL_INIT_ENGINE_ALL_BUILTIN = (OPENSSL_INIT_ENGINE_RDRAND |
                                     OPENSSL_INIT_ENGINE_DYNAMIC |
                                     OPENSSL_INIT_ENGINE_CRYPTODEV |
                                     OPENSSL_INIT_ENGINE_CAPI |
                                     OPENSSL_INIT_ENGINE_PADLOCK)
  class << self
    def personal_recover(message, signature)
      bin_signature = hex_to_bin(signature).bytes.rotate(-1).pack("c*")
      hashed_message = Digest::Keccak.new(256).digest(prefix_message(message))

      recover_compact(hashed_message, bin_signature)
    end

    private

    def recover_compact(hashed_message, signature)
      msg32 = FFI::MemoryPointer.new(:uchar, 32).put_bytes(0, hashed_message)
      version = signature.unpack("C")[0]
      compressed = version >= 31

      recover_public_key_from_signature(msg32.read_string(32), signature, version - 27, compressed)
    end

    def recover_public_key_from_signature(message_hash, signature, rec_id, is_compressed)
      init_ffi_ssl
      signature = FFI::MemoryPointer.from_string(signature)
      r = BN_bin2bn(signature[1], 32, BN_new())
      s = BN_bin2bn(signature[33], 32, BN_new())
      i = rec_id / 2
      eckey = EC_KEY_new_by_curve_name(NID_secp256k1)

      group = EC_KEY_get0_group(eckey)
      order = BN_new()
      EC_GROUP_get_order(group, order, nil)
      x = BN_dup(order)
      BN_mul_word(x, i)
      BN_add(x, x, r)

      field = BN_new()
      EC_GROUP_get_curve_GFp(group, field, nil, nil, nil)

      if BN_cmp(x, field) >= 0
        [r, s, order, x, field].each { |item| BN_free(item) }
        EC_KEY_free(eckey)
        return nil
      end
      big_r = EC_POINT_new(group)
      EC_POINT_set_compressed_coordinates_GFp(group, big_r, x, rec_id % 2, nil)

      big_q = EC_POINT_new(group)
      n = EC_GROUP_get_degree(group)
      e = BN_bin2bn(message_hash, message_hash.bytesize, BN_new())
      BN_rshift(e, e, 8 - (n & 7)) if 8 * message_hash.bytesize > n

      ctx = BN_CTX_new()
      zero = BN_new()
      rr = BN_new()
      sor = BN_new()
      eor = BN_new()
      BN_set_word(zero, 0)
      BN_mod_sub(e, zero, e, order, ctx)
      BN_mod_inverse(rr, r, order, ctx)
      BN_mod_mul(sor, s, rr, order, ctx)
      BN_mod_mul(eor, e, rr, order, ctx)
      EC_POINT_mul(group, big_q, eor, big_r, sor, ctx)
      EC_KEY_set_public_key(eckey, big_q)
      BN_CTX_free(ctx)

      [r, s, order, x, field, e, zero, rr, sor, eor].each { |item| BN_free(item) }
      [big_r, big_q].each { |item| EC_POINT_free(item) }

      length = i2o_ECPublicKey(eckey, nil)
      buf = FFI::MemoryPointer.new(:uint8, length)
      ptr = FFI::MemoryPointer.new(:pointer).put_pointer(0, buf)
      pub_hex = buf.read_string(length).unpack("H*")[0] if i2o_ECPublicKey(eckey, ptr) == length

      EC_KEY_free(eckey)

      pub_hex
    end

    def hex_to_bin(str)
      RLP::Utils.decode_hex(remove_hex_prefix(str))
    end

    def remove_hex_prefix(s)
      s[0, 2] == "0x" ? s[2..-1] : s
    end

    def prefix_message(message)
      "\x19Ethereum Signed Message:\n#{message.length}#{message}"
    end

    def init_ffi_ssl
      OPENSSL_init_ssl(
        OPENSSL_INIT_LOAD_SSL_STRINGS | OPENSSL_INIT_ENGINE_ALL_BUILTIN,
        nil
      )
    end
  end
end
