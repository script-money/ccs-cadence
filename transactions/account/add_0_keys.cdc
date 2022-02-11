// This transaction use for add new key to account for key rotation
transaction(publicKey: String, count: Int) {
    prepare(signer: AuthAccount) {
        let key = PublicKey(
                publicKey: publicKey.decodeHex(),
                signatureAlgorithm: SignatureAlgorithm.ECDSA_P256
            )
        var a = 0
        while a < count {
          signer.keys.add(
              publicKey: key,
              hashAlgorithm: HashAlgorithm.SHA3_256,
              weight: 0.0 as UFix64
          )
          a = a + 1
        }
    }
}