import BallotContract from "../../contracts/BallotContract.cdc"

pub fun main(): UInt64 {    
  return BallotContract.supply
}
