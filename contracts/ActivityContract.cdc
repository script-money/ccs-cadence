import FungibleToken from "./FungibleToken.cdc"
import NonFungibleToken from "./NonFungibleToken.cdc"
import BallotContract from "./BallotContract.cdc"
import Memorials from "./Memorials.cdc"

pub contract ActivityContract {
  // totalSupply
  //
  // Total supply of activity resource in existence
  pub var totalSupply: UInt64

  // createConsumption
  //
  // Number of tokens required to create an activity
  priv var createConsumption: UFix64

  // Named paths
  pub var ActivityStoragePath : StoragePath
  pub var ActivityPublicPath: PublicPath
  pub var ActivityAdminStoragePath: StoragePath
  pub var ActivityModeratorStoragePath: StoragePath

  // activityCreated
  //
  // Event emitted when an activity is created, use for data sync to database
  // id is activity Id, and  metadata will carry more detail data
  pub event activityCreated(id:UInt64, title:String, metadata:String, creator:Address)

  // activityVoted
  //
  // Event emitted when an activity is voted, use for data sync to database
  pub event activityVoted(id:UInt64, voter:Address, isUpVote:Bool)

  // activityClosed
  //
  // Event emitted when an activity is closed, use for data sync to database
  pub event activityClosed(id:UInt64)

  // consumptionUpdated
  //
  // Event emitted when consumption is updated, use for data sync to database
  // Admin can update consumption by sending transaction, need be synced
  pub event consumptionUpdated(newPrice: UFix64)

  // rewardParameterUpdated
  // 
  // Event emitted when reward parameter is updated, use for data sync to database
  // Admin can update rewardParameter by sending transaction, need be synced
  pub event rewardParameterUpdated(newParams: RewardParameter)

  // RewardParameter
  //
  // all rewardParameter use by off-chain compute, it's a asymmetrySigmoid function, javascript code is below
  //
  // /**
  //  * asymmetric curve algorithm
  //  * @param votingRatio function's x value
  //  * @param top f(x) < top
  //  * @param bottom f(x) > bottom
  //  * @param k f(x=votingRatio) = k
  //  * @param s The higher the value of s, the steeper the curve and the more incentive
  //  * @returns f(x)
  //  */
  // const asymmetrySigmoid = (
  //   votingRatio: number,
  //   top: number,
  //   bottom: number,
  //   k: number,
  //   s: number
  // ) => {
  //   const r = (top - bottom) / (k - bottom);
  //   const denominator = Math.pow(
  //     1 + Math.pow(10, 1 + Math.log10(Math.pow(r, 1 / s) - 1) - votingRatio),
  //     s
  //   );
  //   const y = bottom + (top - bottom) / denominator;
  //   return y;
  // };
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

  // direct reference to rewardParameter struct
  priv var rewardParameter: RewardParameter

  // Activity
  //
  // carry the necessary on-chain information for the activity
  pub resource Activity {
    
    // activity title
    pub var title: String

    // activity id, equal totalSupply
    pub var id: UInt64

    // the affirmative votes amount this activity got
    pub var upVoteCount: Int

    // the dissenting votes amount this activity got
    pub var downVoteCount: Int

    // voteResult
    // 
    // the vote result this activity got, it a map
    // key is voter address
    // value is bool, true is upVote, false is downVote
    access(contract) var voteResult: {Address: Bool}

    // activity creator
    pub var creator: Address

    // is activity closed?
    pub var closed: Bool

    // metadata
    //
    // the metadata include more detail information
    // include content/startDate/endDate/source/categories
    pub var metadata: String

    // upVote
    //
    // user can vote activity which not closed
    // upVoteCount and voteResult will update
    access(contract) fun upVote(address: Address){
      pre{
        !self.closed : "activity is closed"
      }
      self.upVoteCount = self.upVoteCount + 1
      self.voteResult.insert(key: address, true)
    }

    // downVote
    //
    // user can vote activity which not closed
    // downVoteCount and voteResult will update
    access(contract) fun downVote(address: Address){
      pre{
        !self.closed : "activity is closed"
      }
      self.downVoteCount = self.downVoteCount + 1
      self.voteResult.insert(key: address, false)
    }

    // close
    //
    // admin can close activity
    access(contract) fun close(){
      pre{
        !self.closed : "activity is closed"
      }
      self.closed = true
    }

    // getter for query voteResult
    pub fun getVoteResult(): {Address: Bool}{
      return self.voteResult
    }

    // initializer
    //
    // preVote for create airdrop activity which directly send memorials(NFT) to users
    init(_creator: Address, _title: String, metadata: String, preVote: {Address:Bool}?){
      self.title = _title
      self.id = ActivityContract.totalSupply
      // the activity creator will automatic affirmative vote activity that he created
      self.upVoteCount = preVote == nil? 1 : preVote!.length
      self.downVoteCount = 0
      // automatic affirmative vote will generate one voter result
      self.voteResult = preVote ?? { _creator: true }
      self.creator = _creator
      // airdrop activity can't vote, will be closed when create
      self.closed = preVote == nil? false : true
      self.metadata = metadata
    }
  }

  // createActivity
  //
  // will spend some CCS token to create activity
  // creator, title, metadata send by transaction
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

    // activity resource will save in admin's collection
    adminActivityCollection.deposit(activity: <-newActivity)

    destroy vault
  }

  // vote
  //
  // user can vote activity which not closed
  // vote need burn one ballot
  // voter, activityId, isUpVote send by transaction
  pub fun vote(ballot: @BallotContract.Ballot, voter: Address, activityId: UInt64, isUpVote: Bool){
    pre{
      // can't vote activity not exist
      ActivityContract.getIDs().contains(activityId): "activityId is not in collection"
      // can't vote activity is voted by voter
      !ActivityContract.checkVoted(id: activityId, address: voter) : "user has voted this activity"
    }

    // get activity reference
    let activityRef = ActivityContract.getActivity(id: activityId)!

    // change Activity vote count by use activity reference function
    if isUpVote {
      activityRef.upVote(address: voter)
    }else {
      activityRef.downVote(address: voter)
    }

    emit activityVoted(id:activityId, voter:voter, isUpVote:isUpVote)

    destroy ballot
  }

  // Collection
  //
  // collection use for save activity to a map, get ids and reference activity
  pub resource Collection{
    // activity should be save in dict
    access(self) var idToActivity: @{UInt64: Activity}

    // deposit activity to collection
    access(contract) fun deposit(activity: @Activity) {
        let oldActivity <- self.idToActivity[activity.id] <- activity
        destroy oldActivity
    }

    // function for get activity IDs
    pub fun getIDs(): [UInt64] {
      return self.idToActivity.keys
    }

    // function for get activity reference
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

    // initializer
    init(){
      self.idToActivity <- {}
    }
  }

  // function for script  get activity by id
  pub fun getActivity(id: UInt64): &Activity? {
    let collection = 
      ActivityContract.account.getCapability(ActivityContract.ActivityPublicPath)
        .borrow<&ActivityContract.Collection>()?? panic("Couldn't get activity collection")
    return collection.borrowActivity(id: id)
  }

  // funciton for script get all activity IDs
  pub fun getIDs(): [UInt64] {
    let collection = ActivityContract.account.getCapability(ActivityContract.ActivityPublicPath)
      .borrow<&ActivityContract.Collection>()?? panic("Couldn't get activity collection")
    return collection.getIDs()
  }

  // fucntion check if activity voted by specific address
  pub fun checkVoted(id: UInt64, address: Address): Bool{
    let activityRef = ActivityContract.getActivity(id: id)!
    return activityRef.voteResult.keys.contains(address)
  }

  // function for script get activity create comsumption
  pub fun getCreateConsumption(): UFix64{
    return ActivityContract.createConsumption
  }

  // function for script get reward parameters
  pub fun getRewardParams(): ActivityContract.RewardParameter{
    return ActivityContract.rewardParameter
  }

  // function for initialise collection storage
  access(self) fun createEmptyCollection(): @Collection {
      return <- create Collection()
  }

  // admin
  //
  // Admin can update consumption, update reward parameter and create new moderator
  pub resource Admin {
    // close activity by id
    pub fun closeActivity(activityId id: UInt64){
      pre{
        // can operate activity id in collection ids
        ActivityContract.getIDs().contains(id): "activityId is not in collection"
      }
      // get activity reference
      let activityRef = ActivityContract.getActivity(id: id)!

      // make activity closed
      if !activityRef.closed {
        activityRef.close()  
        emit activityClosed(id:id)
      }
    }

    // batch mint memrials then send to users, suggest mint 5 once
    pub fun batchMintMemorials(activityId id: UInt64, bonus: UFix64, mintPositive: Bool, voteDict: {Address:Bool}, startFrom: UInt64, isAirdrop: Bool?, TotalCount: UInt64?){      
      // get activity reference
      let activityRef = ActivityContract.getActivity(id: id)!

      assert(activityRef.closed, message: "activity must be closed")

      if(isAirdrop == true){
        assert(TotalCount != nil, message: "TotalCount must not be nil")
      }

      // get Memorials Miner
      let minter = ActivityContract.account.borrow<&Memorials.NFTMinter>(
        from: Memorials.MinterStoragePath
      ) ?? panic("Could not borrow a reference to the NFTMinter")
      
      // get vote result dictionary
      let allVoteDict = activityRef.voteResult

      // use for set memorial NFT's series number
      var i: UInt64 = startFrom

      // two type of memorials can be minted, positive and negative
      if mintPositive {
        // loop for each voter who vote for
        for address in voteDict.keys {
          let isUpVote = isAirdrop == true ? true : voteDict[address]!
          assert(voteDict[address] == allVoteDict[address], message: "import vote result not same result in contract")
          if isUpVote {
            // get voter's public Memorials collection 
            let receiver = getAccount(address)
              .getCapability(Memorials.CollectionPublicPath)!
              .borrow<&{NonFungibleToken.CollectionPublic}>()
              ?? panic("Could not get receiver reference to the NFT Collection")
            // let mmorials miner mint a new memorial to recipient(voter)'s collection
            minter.mintNFT(
              recipient: receiver, 
              seriesNumber: i,
              circulatingCount: isAirdrop == true ? TotalCount! : UInt64(activityRef.upVoteCount),
              activityID: activityRef.id, 
              title: activityRef.title, 
              isPositive: true,
              bonus: bonus,
              metadata: activityRef.metadata
            )
            // series number increment
            i = i + 1
          }
        }  
      } else {
        // loop for each voter who vote against
        for address in voteDict.keys {
          let isUpVote = voteDict[address]!
          assert(voteDict[address] == allVoteDict[address], message: "import vote result not same result in contract")
          if !isUpVote {
            // get voter's public Memorials collection 
            let receiver = getAccount(address)
              .getCapability(Memorials.CollectionPublicPath)!
              .borrow<&{NonFungibleToken.CollectionPublic}>()
              ?? panic("Could not get receiver reference to the NFT Collection")
            // let mmorials miner mint a new memorial to recipient(voter)'s collection
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
            // series number increment
            i = i + 1
          }
        }
      }
    }
    
    // function for update activity consumption
    pub fun updateConsumption(new: UFix64){
      pre{ 
        new > 0.0 : "new consumption should great than 0"
      }
      ActivityContract.createConsumption = new
      emit consumptionUpdated(newPrice: new)
    }

    // function for update reward parameter
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

    // For business need, admin can create a new activity moderator resource
    pub fun createModerator(): @Moderator {
        return <- create Moderator()
    }
  }

  /// moderator
  //
  // moderator can close activity and create airdrop activity
  pub resource Moderator
  {
    // closeActivity
    // 
    // moderator can close negetive activity
    pub fun closeActivity(activityId id: UInt64){
      let admin = ActivityContract.account.borrow<&ActivityContract.Admin>(
        from: ActivityContract.ActivityAdminStoragePath
      ) ?? panic("Could not borrow a reference to the Admin Reference")
      admin.closeActivity(activityId: id)
    }
  }

  // initializer
  init(){
    // activity supply is 0 at first
    self.totalSupply = 0

    // reward parameter will be set default value
    self.rewardParameter = RewardParameter(maxRatio:5.0, minRatio:1.0, averageRatio:1.5, asymmetry: 2.0)
    
    // Set our named paths
    // remove _0x when mainnet deploy
    self.ActivityStoragePath = /storage/ActivitiesCollection_0
    self.ActivityPublicPath = /public/ActivitiesCollection_0
    self.ActivityAdminStoragePath = /storage/ActivityAdmin_0
    self.ActivityModeratorStoragePath = /storage/ActivityModerator_0

    // set admin account
    let admin <- create Admin()
    self.account.save(<-admin, to: self.ActivityAdminStoragePath)
    self.account.save(<-ActivityContract.createEmptyCollection(), to: self.ActivityStoragePath) 
    self.account.link<&ActivityContract.Collection>(self.ActivityPublicPath, target: self.ActivityStoragePath)
    
    let moderator <- create Moderator()
    self.account.save(<-moderator, to: self.ActivityModeratorStoragePath)

    // set create consumption to 100 ccs token
    self.createConsumption = 100.0
  }
}
 