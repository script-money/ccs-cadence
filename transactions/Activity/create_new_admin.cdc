import ActivityContract from "../../contracts/ActivityContract.cdc"

transaction() {
    prepare(signer: AuthAccount, admin: AuthAccount) {
      let admin = admin.borrow<&ActivityContract.Admin>(
        from: ActivityContract.ActivityAdminStoragePath
      ) ?? panic("Could not borrow a reference to the activity admin")

      signer.save(<- admin.createModerator(), to: ActivityContract.ActivityModeratorStoragePath)

      signer.borrow<&ActivityContract.Moderator>(
        from: ActivityContract.ActivityModeratorStoragePath
      ) ?? panic("signer isn't become activity moderator")
    }
}
