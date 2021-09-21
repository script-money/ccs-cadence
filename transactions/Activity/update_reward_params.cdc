import ActivityContract from "../../contracts/ActivityContract.cdc"

transaction(newParameter: {String: UFix64}) {
    
    // local variable for storing the minter reference
    let admin: &ActivityContract.Admin

    prepare(signer: AuthAccount) {
      // borrow a reference to the activityAdmin resource in storage
      self.admin = signer.borrow<&ActivityContract.Admin>(
        from: ActivityContract.ActivityAdminStoragePath
      ) ?? panic("Could not borrow a reference to the activity admin")
    }

    execute {
      let oldParams = ActivityContract.getRewardParams()
      let newParams = ActivityContract.RewardParameter(
          maxRatio : newParameter["maxRatio"]!,
          minRatio : newParameter["minRatio"]!,
          averageRatio :newParameter["averageRatio"]!,
          asymmetry : newParameter["asymmetry"]!
      )
      self.admin.updateRewardParameter(newParams)
    }
}
