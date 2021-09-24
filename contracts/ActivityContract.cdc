import FungibleToken from "./FungibleToken.cdc"
import NonFungibleToken from "./NonFungibleToken.cdc"
import BallotContract from "./BallotContract.cdc"
import Memorials from "./Memorials.cdc"

pub contract ActivityContract {

  pub var totalSupply: UInt64
  priv var createConsumption: UFix64
  pub var ActivityStoragePath : StoragePath
  pub var ActivityPublicPath: PublicPath
  pub var ActivityAdminStoragePath: StoragePath

  pub event activityCreated(id:UInt64, title:String, metadata:String, creator:Address)
  pub event activityVoted(id:UInt64, voter:Address, isUpVote:Bool)
  pub event activityClosed(id:UInt64, bonus: UFix64, mintPositive: Bool, voteResult:{Address: Bool})
  pub event consumptionUpdated(newPrice: UFix64)
  pub event rewardParameterUpdated(newParams: RewardParameter)

  // all rewardParameter use by off-chain compute
  pub struct RewardParameter{
    pub var maxRatio: UFix64
    pub var minRatio: UFix64
    // if get average vote compare past activities, can get averageRatio * createConsumption CCS reward
    pub var averageRatio: UFix64
    pub var asymmetry: UFix64

    init(maxRatio:UFix64, minRatio:UFix64, averageRatio:UFix64, asymmetry: UFix64){
      self.maxRatio = maxRatio
      self.minRatio = minRatio
      self.averageRatio = averageRatio
      self.asymmetry = asymmetry
    }
  }

  priv var rewardParameter: RewardParameter

  pub resource Activity {
    pub var title: String
    pub var id: UInt64
    pub var upVoteCount: Int
    pub var downVoteCount: Int
    access(contract) var voteResult: {Address: Bool}
    pub var creator: Address
    pub var closed: Bool
    pub var metadata: String

    access(contract) fun upVote(address: Address){
      pre{
        !self.closed : "activity is closed"
      }
      self.upVoteCount = self.upVoteCount + 1
      self.voteResult.insert(key: address, true)
    }

    access(contract) fun downVote(address: Address){
      pre{
        !self.closed : "activity is closed"
      }
      self.downVoteCount = self.downVoteCount + 1
      self.voteResult.insert(key: address, false)
    }

    access(contract) fun close(){
      pre{
        !self.closed : "activity is closed"
      }
      self.closed = true
    }

    pub fun getVoteResult(): {Address: Bool}{
      return self.voteResult
    }

    init(_creator: Address, _title: String, metadata: String, preVote: {Address:Bool}?){
      self.title = _title
      self.id = ActivityContract.totalSupply
      self.upVoteCount = preVote == nil? 1 : preVote!.length
      self.downVoteCount = 0
      self.voteResult = preVote ?? { _creator: true }
      self.creator = _creator
      self.closed = preVote == nil? false : true
      self.metadata = metadata
    }
  }

  pub fun createActivity(vault: @FungibleToken.Vault, creator: Address, title: String, metadata: String){
    pre {
      vault.balance == ActivityContract.createConsumption
        : "Send vault must same as createConsumption"
      title.length != 0: "Title should not be empty"
    }

    let newActivity <- create Activity(
      _creator: creator, 
      _title: title, 
      metadata: metadata,
      preVote: nil
    )
    emit activityCreated(id:self.totalSupply, title:title, metadata:metadata, creator:creator)
    self.totalSupply = self.totalSupply + (1 as UInt64)

    let adminActivityCollection = ActivityContract.account
      .borrow<&ActivityContract.Collection>(from: ActivityContract.ActivityStoragePath)!

    adminActivityCollection.deposit(activity: <-newActivity)
    destroy vault
  }

  pub fun vote(ballot: @BallotContract.Ballot, voter: Address, activityId: UInt64, isUpVote: Bool){
    pre{
      ActivityContract.getIDs().contains(activityId): "activityId is not in collection"
      !ActivityContract.checkVoted(id: activityId, address: voter) : "user has voted this activity"
    }
    // get activity reference
    let activityRef = ActivityContract.getActivity(id: activityId)!
    // change Activity status
    if isUpVote {
      activityRef.upVote(address: voter)
    }else {
      activityRef.downVote(address: voter)
    }
    emit activityVoted(id:activityId, voter:voter, isUpVote:isUpVote)
    destroy ballot
  }

  pub resource Collection{
    // activity should be save in dict
    access(self) var idToActivity: @{UInt64: Activity}

    access(contract) fun deposit(activity: @Activity) {
        let oldActivity <- self.idToActivity[activity.id] <- activity
        destroy oldActivity
    }

    pub fun getIDs(): [UInt64] {
      return self.idToActivity.keys
    }

    access(contract) fun borrowActivity(id: UInt64): &Activity? {
      if self.idToActivity.containsKey(id) {
        let activityRef: &Activity = &self.idToActivity[id] as &Activity
        return activityRef
      }
      return nil
    }

    destroy(){
      destroy self.idToActivity
    }

    init(){
      self.idToActivity <- {}
    }
  }

  pub fun getActivity(id: UInt64): &Activity? {
    let collection = 
      ActivityContract.account.getCapability(ActivityContract.ActivityPublicPath).borrow<&ActivityContract.Collection>()?? panic("Couldn't get activity collection")
    return collection.borrowActivity(id: id)
  }

  pub fun getIDs(): [UInt64] {
    let collection = ActivityContract.account.getCapability(ActivityContract.ActivityPublicPath).borrow<&ActivityContract.Collection>()?? panic("Couldn't get activity collection")
    return collection.getIDs()
  }

  pub fun checkVoted(id: UInt64, address: Address): Bool{
    let activityRef = ActivityContract.getActivity(id: id)!
    return activityRef.voteResult.keys.contains(address)
  }

  pub fun getCreateConsumption(): UFix64{
    return ActivityContract.createConsumption
  }

  pub fun getRewardParams(): ActivityContract.RewardParameter{
    return ActivityContract.rewardParameter
  }

  access(self) fun createEmptyCollection(): @Collection {
      return <- create Collection()
  }

  pub resource Admin {
    // bonus and mintPositive are computed off blockchain
    pub fun closeActivity(activityId id: UInt64, bonus: UFix64, mintPositive: Bool){
      pre{
        ActivityContract.getIDs().contains(id): "activityId is not in collection"
      }
      // get activity reference
      let activityRef = ActivityContract.getActivity(id: id)!
      if !activityRef.closed {
        activityRef.close()  
      }

      // let Memorials Miner Mint NFTs
      let minter = ActivityContract.account.borrow<&Memorials.NFTMinter>(
        from: Memorials.MinterStoragePath
      ) ?? panic("Could not borrow a reference to the NFTMinter")
      
      let voteDict = activityRef.voteResult
      var i: UInt64 = 1

      if mintPositive {
        for address in voteDict.keys {
          assert(address != nil, message: "Can not get reciever address")
          let isUpVote = activityRef.voteResult[address]!

          if isUpVote {
            let receiver = getAccount(address)
              .getCapability(Memorials.CollectionPublicPath)!
              .borrow<&{NonFungibleToken.CollectionPublic}>()
              ?? panic("Could not get receiver reference to the NFT Collection")
            minter.mintNFT(
              recipient: receiver, 
              seriesNumber: i,
              circulatingCount: UInt64(activityRef.upVoteCount),
              activityID: activityRef.id, 
              title: activityRef.title, 
              isPositive: true,
              bonus: bonus,
              metadata: activityRef.metadata
            )
            i = i + 1
          }
        }  
      } else {
        for address in voteDict.keys {
          assert(address != nil, message: "Can not get reciever address")
          let isUpVote = activityRef.voteResult[address]!
          if !isUpVote {
            let receiver = getAccount(address)
              .getCapability(Memorials.CollectionPublicPath)!
              .borrow<&{NonFungibleToken.CollectionPublic}>()
              ?? panic("Could not get receiver reference to the NFT Collection")
            // mint the NFT and deposit it to the recipient's collection
            minter.mintNFT(
              recipient: receiver, 
              seriesNumber: i,
              circulatingCount:UInt64(activityRef.downVoteCount),
              activityID: activityRef.id, 
              title: activityRef.title, 
              isPositive: false,
              bonus: bonus,
              metadata: activityRef.metadata
            )
            i = i + 1
          }
        }
      }

      emit activityClosed(id:id, bonus:bonus, mintPositive:mintPositive, voteResult: voteDict)
    }

    pub fun createAirdrop(title:String, recievers:[Address], bonus:UFix64, metadata: String){
      pre {
        title.length != 0: "Title should not be empty"
        recievers.length != 0: "recievers should at least 1 address"
      }

      let recieverVotes:{Address:Bool} = {}
      for reciever in recievers{
        recieverVotes.insert(key: reciever, true)
      }

      let newActivity <- create Activity(
        _creator: ActivityContract.account.address, 
        _title: title, 
        metadata: metadata, 
        preVote: recieverVotes
      )
      ActivityContract.totalSupply = ActivityContract.totalSupply + (1 as UInt64)
      
      let adminActivityCollection = ActivityContract.account
        .borrow<&ActivityContract.Collection>(from: ActivityContract.ActivityStoragePath)!

      let newActivityRef = &newActivity as &ActivityContract.Activity
      adminActivityCollection.deposit(activity: <-newActivity)

      // close activity
      self.closeActivity(activityId: newActivityRef.id, bonus: bonus, mintPositive: true) 
    }
    
    pub fun updateConsumption(new: UFix64){
      pre{ 
        new > 0.0 : "new consumption should great than 0"
      }
      ActivityContract.createConsumption = new
      emit consumptionUpdated(newPrice: new)
    }

    pub fun updateRewardParameter(_ new: ActivityContract.RewardParameter){
      pre{
        new.minRatio >= 1.0: "minRatio should gte 1.0"
        new.maxRatio > new.minRatio: "maxRatio should greater than minRatio"
        new.averageRatio > new.minRatio: "averageRatio should gt minRatio"
        new.averageRatio < new.maxRatio: "averageRatio should lt maxRatio"
        new.asymmetry > 0.0: "asymmetry should greater than 0"
      }
      ActivityContract.rewardParameter = new
      emit rewardParameterUpdated(newParams: new)
    }

    // For business need, admin can create a new activityAdmin resource
    pub fun createAdmin(): @Admin {
        return <- create Admin()
    }
  }

  
  init(){
    self.totalSupply = 0
    self.rewardParameter = RewardParameter(maxRatio:5.0, minRatio:1.0, averageRatio:1.5, asymmetry: 2.0)
    self.ActivityStoragePath = /storage/ActivitiesCollection
    self.ActivityPublicPath = /public/ActivitiesCollection
    self.ActivityAdminStoragePath = /storage/ActivityAdmin

    let admin <- create Admin()
    self.account.save(<-admin, to: self.ActivityAdminStoragePath)

    self.account.save(<-ActivityContract.createEmptyCollection(), to: self.ActivityStoragePath) 
    self.account.link<&ActivityContract.Collection>(self.ActivityPublicPath, target: self.ActivityStoragePath)
    
    // set create consumption to 100, equal about 50 ballot CCS token destory amount
    self.createConsumption = 100.0
  }
}
 