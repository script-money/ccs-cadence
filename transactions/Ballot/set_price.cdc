import BallotContract from "../../contracts/BallotContract.cdc"

transaction(price: UFix64) {
  let AdminRef: &BallotContract.Admin

  prepare(signer: AuthAccount) {
    self.AdminRef = signer.borrow<&BallotContract.Admin>(from: BallotContract.AdminStoragePath)
      ?? panic("can not borrow admin resource")
  }

  execute{
    self.AdminRef.setPrice(newPrice: price)
  }
}
