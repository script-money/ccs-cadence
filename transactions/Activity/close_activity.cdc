import ActivityContract from "../../contracts/ActivityContract.cdc"

transaction(_activityID: UInt64) {
    
    // local variable for storing the minter reference
    let moderator: &ActivityContract.Moderator

    prepare(signer: AuthAccount) {

      // borrow a reference to the activityAdmin resource in storage
      self.moderator = signer.borrow<&ActivityContract.Moderator>(
        from: ActivityContract.ActivityModeratorStoragePath
      ) ?? panic("Could not borrow a reference to the activity moderator resource")
    }

    execute {
      self.moderator.closeActivity(activityId: _activityID)
    }
}
