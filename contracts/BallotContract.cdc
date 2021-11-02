import FungibleToken from "./FungibleToken.cdc"
import CCSToken from "./CCSToken.cdc"

pub contract BallotContract {
  // Total supply of ballot resource in existence
  pub var supply: UInt64

  // how much spend buy a ballot
  pub var price: UFix64

  // Named paths
  pub var CollectionStoragePath: StoragePath
  pub var CollectionPublicPath: PublicPath
  pub var AdminStoragePath: StoragePath

  // event somebody buy a ballot
  pub event ballotsBought(amount: Int, buyer: Address, price: UFix64)

  // event somebody setup account
  pub event ballotPrepared(address: Address)

  // ballot resource, no any logic and fields
  pub resource Ballot {

  }

  // interface for public access
  pub resource interface CollectionPublic{
    pub fun getAmount(): Int
  }

  // Collection
  //
  // collection for user managing his/her ballots
  pub resource Collection: CollectionPublic{
    // ballots array user own
    access(self) var ownedBallots: @[Ballot]

    // how much ballots user own
    pub fun getAmount(): Int {
      return self.ownedBallots.length
    }

    // add a new ballot to user collection
    pub fun save(ballots: @[Ballot]){
      pre{
        ballots.length >= 1: "ballots length should be at least 1 when save"
      }
      var i = 0
      let fixLength = ballots.length
      while i < fixLength {
        self.ownedBallots.append(<- ballots.removeFirst()) 
        i = i + 1
      }
      emit ballotsBought(amount: fixLength, buyer: self.ownedBallots[0].owner!.address, price: BallotContract.price)
      destroy ballots
    }

    // remove a ballot from user collection
    pub fun borrow(): @Ballot {
      pre {
        self.ownedBallots.length >= 1: "User need has a ballot at least"
      }
      return <- self.ownedBallots.removeLast()
    }

    // initializer
    init(){
      self.ownedBallots <- []
    }

    destroy() {
      destroy self.ownedBallots
    }
  }

  // buyBallots
  //
  // spend some token to buy ballots, return ballots array resource to save
  pub fun buyBallots(amount: Int, buyTokens: @FungibleToken.Vault): @[Ballot]{
    pre {
      amount >= 1: "Should buy at least 1 ballot"
      buyTokens.isInstance(Type<@CCSToken.Vault>()):
        "Only Flow Tokens are supported for purchase"
      buyTokens.balance == BallotContract.price * UFix64(amount)
        : "Send vault must same as ballot price * amount"
    }
    var i = 0
    // create an empty array to save ballots
    var ballots: @[Ballot] <- []
    
    // loop to create ballot then append to array
    while i < amount{
      ballots.append( <-create Ballot() )
      BallotContract.supply = BallotContract.supply + 1
      i = i + 1
    }
    // tokens use buy ballots should be destoryed
    destroy buyTokens
    return <- ballots
  }

  // setup account for user save ballots
  pub fun createEmptyCollection(_ address: Address): @Collection{
    emit ballotPrepared(address: address)
    return <- create Collection()
  }

  // admin
  //
  // admin resource for managing ballot price
  pub resource Admin {
    // admin can setup a new price for ballots
    pub fun setPrice(newPrice: UFix64){
      pre {
        newPrice >= 0.0: "price should greate than 0"
      }
      BallotContract.price = newPrice
    }
  } 

  // initializer
  init(){
    // ballot supply is 0 at first
    self.supply = 0
    
    // ballot price is 0.1 by default
    self.price = 1.0

    // Set our named paths
    // remove _0x when mainnet deploy
    self.CollectionStoragePath = /storage/BallotCollectionStoragePath_0
    self.CollectionPublicPath = /public/BallotCollectionPublicPath_0
    self.AdminStoragePath = /storage/BallotCollectionAdminStoragePath_0

    // set admin account
    let admin <- create Admin()
    self.account.save(<-admin, to: self.AdminStoragePath)
  }
}