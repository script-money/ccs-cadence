import BallotContract from "../../contracts/BallotContract.cdc"

transaction {
  prepare(signer: AuthAccount) {
    if signer.borrow<&BallotContract.Collection>(from: BallotContract.CollectionStoragePath) == nil {
      signer.save(<-BallotContract.createEmptyCollection(), to: BallotContract.CollectionStoragePath)

      signer.link<&BallotContract.Collection>(
          BallotContract.CollectionPublicPath,
          target: BallotContract.CollectionStoragePath
      )
    }
  }
}
