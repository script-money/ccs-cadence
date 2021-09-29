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
    .getCapability<&BallotContract.Collection{BallotContract.CollectionPublic}>(BallotContract.CollectionPublicPath)
    .check()
}

pub fun hasMomerials(_ address: Address): Bool {
  return getAccount(address)
    .getCapability<&Memorials.Collection{NonFungibleToken.CollectionPublic, Memorials.MemorialsCollectionPublic}>(Memorials.CollectionPublicPath)
    .check()
}

pub fun main(address: Address): {String: Bool} {
  let ret: {String: Bool} = {}
  ret["CCSToken"] = hasCCSToken(address)
  ret["Ballot"] = hasBallot(address)
  ret["Momerials"] = hasMomerials(address)
  return ret
}