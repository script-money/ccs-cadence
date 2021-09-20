import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import Memorials from "../../contracts/Memorials.cdc"

pub fun main(address: Address): UFix64 {
  let collectionRef = getAccount(address).getCapability(Memorials.CollectionPublicPath)!
      .borrow<&{Memorials.MemorialsCollectionPublic}>()
      ?? panic("Could not borrow capability from public collection")
  return collectionRef.getVotingPower()
}