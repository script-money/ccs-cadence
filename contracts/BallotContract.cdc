import FungibleToken from "./FungibleToken.cdc"
import CCSToken from "./CCSToken.cdc"

pub contract BallotContract {
  pub var supply: UInt64
  pub var price: UFix64
  pub var CollectionStoragePath: StoragePath
  pub var CollectionPublicPath: PublicPath
  pub var AdminStoragePath: StoragePath

  pub resource Ballot {

  }

  pub resource Collection{
    pub var ownedBallots: @[Ballot]

    pub fun getAmount(): Int {
      return self.ownedBallots.length
    }

    pub fun save(ballots: @[Ballot]){
      var i = 0
      let fixLength = ballots.length
      while i < fixLength {
        self.ownedBallots.append(<- ballots.removeFirst()) 
        i = i + 1
      }
      destroy ballots
    }

    pub fun borrow(): @Ballot {
      pre {
        self.ownedBallots.length >= 1: "User need has a ballot at least"
      }
      return <- self.ownedBallots.removeLast()
    }

    init(){
      self.ownedBallots <- []
    }

    destroy() {
      destroy self.ownedBallots
    }
  }

  pub fun buyBallots(amount: Int, buyTokens: @FungibleToken.Vault): @[Ballot]{
    pre {
      buyTokens.isInstance(Type<@CCSToken.Vault>()):
        "Only Flow Tokens are supported for purchase."
      buyTokens.balance == BallotContract.price * UFix64(amount)
        : "Send vault must same as ballot price * amount"
    }
    var i = 0
    var ballots: @[Ballot] <- []
    
    while i < amount{
      ballots.append( <-create Ballot() )
      BallotContract.supply = BallotContract.supply + 1
      i = i + 1
    }
    destroy buyTokens
    return <- ballots
  }

  pub fun createEmptyCollection(): @Collection{
    return <- create Collection()
  }

  pub resource Admin {
    pub fun setPrice(newPrice: UFix64){
      pre {
        newPrice != BallotContract.price : "new price should not same with old price"
        newPrice >= 0.0: "price should greate than 0"
      }
      BallotContract.price = newPrice
    }
  } 

  init(){
    self.supply = 0
    self.price = 1.0
    self.CollectionStoragePath = /storage/BallotCollectionStoragePath
    self.CollectionPublicPath = /public/BallotCollectionPublicPath
    self.AdminStoragePath = /storage/BallotCollectionAdminStoragePath

    let admin <- create Admin()
    self.account.save(<-admin, to: self.AdminStoragePath)
  }
}