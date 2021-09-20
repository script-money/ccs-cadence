import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import Memorials from "../../contracts/Memorials.cdc"

pub struct MemorialItem {
  pub let id: UInt64
  pub let version: UInt8
  pub let seriesNumber: UInt64
  pub let circulatingCount: UInt64
  pub let activityID: UInt64
  pub let title: String
  pub let timestamp: UFix64
  pub let isPositive: Bool
  pub let bonus: UFix64
  pub let metadata: String
  pub let resourceID: UInt64
  pub let owner: Address

  init(id: UInt64, version: UInt8, seriesNumber: UInt64, circulatingCount: UInt64, 
    activityID: UInt64, title: String, timestamp: UFix64, isPositive: Bool, 
    bonus: UFix64, metadata: String, resourceID: UInt64,  owner: Address) {
    self.id = id
    self.version = version
    self.seriesNumber = seriesNumber
    self.circulatingCount = circulatingCount
    self.activityID = activityID
    self.title = title
    self.timestamp = timestamp
    self.isPositive = isPositive
    self.bonus = bonus
    self.metadata = metadata
    self.resourceID = resourceID
    self.owner = owner
  }
}

pub fun main(address: Address, itemID: UInt64): MemorialItem? {
  if let collection = getAccount(address).getCapability<&Memorials.Collection{NonFungibleToken.CollectionPublic, Memorials.MemorialsCollectionPublic}>(Memorials.CollectionPublicPath).borrow() {
    if let item = collection.borrowMemorial(id: itemID) {
      return MemorialItem(
        id: itemID, 
        version: item.version,
        seriesNumber: item.seriesNumber,
        circulatingCount: item.circulatingCount,
        activityID: item.activityID,
        title: item.title,
        timestamp: item.timestamp,
        isPositive: item.isPositive, 
        bonus: item.bonus,
        metadata: item.metadata,
        resourceID: item.uuid, 
        owner: address
      )
    }
  }

  return nil
}