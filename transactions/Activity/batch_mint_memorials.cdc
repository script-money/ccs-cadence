import ActivityContract from "../../contracts/ActivityContract.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import CCSToken from "../../contracts/CCSToken.cdc"

transaction(
    activityId:UInt64, bonus:UFix64, mintPositive: Bool, voteDict: {Address:Bool}, 
    startFrom: UInt64, isAirdrop: Bool?, TotalCount: UInt64?
  ) {
    let adminRef: &ActivityContract.Admin

    prepare(signer: AuthAccount) {
      self.adminRef = signer.borrow<&ActivityContract.Admin>(from: ActivityContract.ActivityAdminStoragePath)
			?? panic("Could not borrow admin's resource in activityContract!")
    }

    execute{
      self.adminRef.batchMintMemorials(
        activityId: activityId, 
        bonus: bonus, 
        mintPositive: mintPositive, 
        voteDict: voteDict, 
        startFrom: startFrom, 
        isAirdrop: isAirdrop, 
        TotalCount: TotalCount
      )
    }
}
 