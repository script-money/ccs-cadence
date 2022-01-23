import ActivityContract from "../../contracts/ActivityContract.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import CCSToken from "../../contracts/CCSToken.cdc"

transaction(title:String, recievers:[Address], bonus:UFix64, metadata: String) {
    // local variable for storing the minter reference
    let moderator: &ActivityContract.Moderator

    prepare(signer: AuthAccount) {

      // borrow a reference to the activityModerator resource in storage
      self.moderator = signer.borrow<&ActivityContract.Moderator>(
        from: ActivityContract.ActivityModeratorStoragePath
      ) ?? panic("Could not borrow a reference to the activity moderator")
    }

    execute {
      self.moderator.createAirdrop(title: title, recievers: recievers, bonus: bonus, metadata: metadata)
    }
}
