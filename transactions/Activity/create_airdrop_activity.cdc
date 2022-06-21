import ActivityContract from "../../contracts/ActivityContract.cdc"

transaction(title: String, metadata: String, airdropList: [Address]) {
  // local variable for storing the minter reference
  let moderator: &ActivityContract.Moderator
  let signerAddress: Address

  prepare(signer: AuthAccount) {
    self.signerAddress = signer.address
    // borrow a reference to the activityAdmin resource in storage
    self.moderator = signer.borrow<&ActivityContract.Moderator>(
      from: ActivityContract.ActivityModeratorStoragePath
    ) ?? panic("Could not borrow a reference to the activity moderator resource")
  }

  execute{
    self.moderator.createAirdropActivity(
      creator: self.signerAddress, 
      title: title, 
      metadata: metadata, 
      toList: airdropList
    )
  }
}