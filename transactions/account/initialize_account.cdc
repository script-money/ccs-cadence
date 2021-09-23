import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import Memorials from "../../contracts/Memorials.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import CCSToken from "../../contracts/CCSToken.cdc"
import BallotContract from "../../contracts/BallotContract.cdc"

pub fun hasCCSToken(_ address: Address): Bool {
  let receiver = getAccount(address)
    .getCapability<&CCSToken.Vault{FungibleToken.Receiver}>(CCSToken.ReceiverPublicPath)
    .check()

  let balance = getAccount(address)
    .getCapability<&CCSToken.Vault{FungibleToken.Balance}>(CCSToken.BalancePublicPath)
    .check()

  return receiver && balance
}

pub fun hasBallot(_ address: Address): Bool {
  return getAccount(address)
    .getCapability<&BallotContract.Collection>(BallotContract.CollectionPublicPath)
    .check()
}

pub fun hasMomerials(_ address: Address): Bool {
  return getAccount(address)
    .getCapability<&Memorials.Collection{NonFungibleToken.CollectionPublic, Memorials.MemorialsCollectionPublic}>(Memorials.CollectionPublicPath)
    .check()
}

transaction {
  prepare(acct: AuthAccount) {
    if !hasCCSToken(acct.address) {
      if acct.borrow<&CCSToken.Vault>(from: CCSToken.VaultStoragePath) == nil {
        acct.save(<-CCSToken.createEmptyVault(), to: CCSToken.VaultStoragePath)
      }
      acct.unlink(CCSToken.ReceiverPublicPath)
      acct.unlink(CCSToken.BalancePublicPath)
      acct.link<&CCSToken.Vault{FungibleToken.Receiver}>(CCSToken.ReceiverPublicPath,target: CCSToken.VaultStoragePath)
      acct.link<&CCSToken.Vault{FungibleToken.Balance}>(CCSToken.BalancePublicPath,target: CCSToken.VaultStoragePath)
    }

    if !hasBallot(acct.address) {
      if acct.borrow<&BallotContract.Collection>(from: BallotContract.CollectionStoragePath) == nil {
        acct.save(<-BallotContract.createEmptyCollection(), to: BallotContract.CollectionStoragePath)
      }
      acct.unlink(BallotContract.CollectionPublicPath)
      acct.link<&BallotContract.Collection{BallotContract.CollectionPublic}>(BallotContract.CollectionPublicPath,target: BallotContract.CollectionStoragePath)
    }

    if !hasMomerials(acct.address) {
      if acct.borrow<&Memorials.Collection>(from: Memorials.CollectionStoragePath) == nil {
        acct.save(<- Memorials.createEmptyCollection(), to: Memorials.CollectionStoragePath)
      }
      acct.unlink(Memorials.CollectionPublicPath)
      acct.link<&Memorials.Collection{NonFungibleToken.CollectionPublic, Memorials.MemorialsCollectionPublic}>(Memorials.CollectionPublicPath, target: Memorials.CollectionStoragePath)
    }
  }
}