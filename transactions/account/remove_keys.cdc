// This transaction use for remove account key
transaction(index: Int) {
    let signer: AuthAccount
    prepare(signer: AuthAccount) {
      self.signer = signer
    }
    pre {
      index != 0
    }
    execute {
        self.signer.removePublicKey(index)
    }
}