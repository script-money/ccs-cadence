import FungibleToken from "../../contracts/FungibleToken.cdc"
import BallotContract from "../../contracts/BallotContract.cdc"

pub fun main(address: Address): Int {
    let account = getAccount(address)
    
    let ballotCollectionRef = account.getCapability(BallotContract.CollectionPublicPath)
      .borrow<&BallotContract.Collection{BallotContract.CollectionPublic}>()
      ?? panic("Could not borrow BallotContract Collection reference")

    return ballotCollectionRef.getAmount()
}
