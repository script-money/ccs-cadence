import ActivityContract from "../../contracts/ActivityContract.cdc"

transaction(newConsumption: UFix64) {
    
    // local variable for storing the minter reference
    let admin: &ActivityContract.Admin

    prepare(signer: AuthAccount) {

      // borrow a reference to the activityAdmin resource in storage
      self.admin = signer.borrow<&ActivityContract.Admin>(
        from: ActivityContract.ActivityAdminStoragePath
      ) ?? panic("Could not borrow a reference to the activity admin")
    }

    execute {
      self.admin.updateConsumption(new: newConsumption)
    }
}
