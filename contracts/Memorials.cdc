import NonFungibleToken from "./NonFungibleToken.cdc"

pub contract Memorials: NonFungibleToken{
  // event when Memorials contract is deployed
  pub event ContractInitialized()

  // The event that is emitted when memorial are withdrawn from a collection
  pub event Withdraw(id: UInt64, from: Address?)

  // The event that is emitted when memorial are deposit from a collection
  pub event Deposit(id: UInt64, to: Address?)

  // The event that is emitted when memorial are minted
  pub event memorialMinted(
    version: UInt8,
    reciever: Address,
    memorialId: UInt64, 
    seriesNumber: UInt64, 
    circulatingCount: UInt64, 
    activityID: UInt64,
    isPositive: Bool,
    bonus: UFix64
  )

  // Named Paths
  //
  pub let CollectionStoragePath: StoragePath
  pub let CollectionPublicPath: PublicPath
  pub let MinterStoragePath: StoragePath

  // totalSupply
  //
  // The total number of Memorials that have been minted
  pub var totalSupply: UInt64

  // version
  //
  // use version to control behaviour, upgrade in future
  pub var version: UInt8

  // use for compute votingPower
  priv var initVotingPower: UFix64

  // NFT
  // 
  // A Memorial as an NFT
  pub resource NFT: NonFungibleToken.INFT {
      pub let id: UInt64
      pub let version: UInt8
      pub let seriesNumber: UInt64
      pub let circulatingCount: UInt64
      pub let activityID: UInt64
      pub let title: String
      pub let isPositive: Bool
      pub let bonus: UFix64
      pub let metadata: String

      // initializer
      //
      init(
        initID: UInt64, seriesNumber:UInt64, 
        circulatingCount: UInt64, activityID: UInt64, 
        title:String, isPositive: Bool, bonus:UFix64,
        metadata: String
      ) {
        self.id = initID
        self.version = Memorials.version
        self.activityID = activityID
        self.seriesNumber = seriesNumber
        self.circulatingCount = circulatingCount
        self.title = title
        self.isPositive = isPositive
        self.bonus = bonus
        self.metadata = metadata
      }
  }

  // This is the interface that users can cast their Memorials Collection as
  // to allow others to deposit Memorials into their Collection. It also allows for reading
  // the details of Memorials in the Collection.
  pub resource interface MemorialsCollectionPublic {
    pub fun deposit(token: @NonFungibleToken.NFT)
    pub fun getIDs(): [UInt64]
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
    pub fun borrowMemorial(id: UInt64): &Memorials.NFT? {
      // If the result isn't nil, the id of the returned reference
      // should be the same as the argument to the function
      post {
          (result == nil) || (result?.id == id):
              "Cannot borrow Memorials reference: The ID of the returned reference is incorrect"
      }
    }
    pub fun getVotingPower(): UFix64
  }

  // Collection
  //
  // collection for user managing his/her ballots, should implement MemorialsCollectionPublic and interfaces in NonFungibleToken
  pub resource Collection: MemorialsCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic {
    // dictionary of NFT conforming tokens
    pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

    // withdraw
    //
    // Removes an NFT from the collection and moves it to the caller
    pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
        let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

        emit Withdraw(id: token.id, from: self.owner?.address)

        return <-token
    }

    // deposit
    //
    // Takes a NFT and adds it to the collections dictionary
    // and adds the ID to the id array
    pub fun deposit(token: @NonFungibleToken.NFT) {
        let token <- token as! @Memorials.NFT

        let id: UInt64 = token.id

        // add the new token to the dictionary which removes the old one
        let oldToken <- self.ownedNFTs[id] <- token

        emit Deposit(id: id, to: self.owner?.address)

        destroy oldToken
    }

    // getIDs
    // 
    // Returns an array of the IDs that are in the collection
    pub fun getIDs(): [UInt64] {
        return self.ownedNFTs.keys
    }

    // borrowNFT
    //
    // Gets a reference to an NFT in the collection
    // so that the caller can read its metadata and call its methods
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
        return &self.ownedNFTs[id] as &NonFungibleToken.NFT
    }

    // borrowMemorials
    //
    // Gets a reference to an NFT in the collection as a Memorials,
    // exposing all of its fields
    // This is safe as there are no functions that can be called on the Memorials.
    pub fun borrowMemorial(id: UInt64): &Memorials.NFT? {
        if self.ownedNFTs[id] != nil {
            let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT
            return ref as! &Memorials.NFT
        } else {
            return nil
        }
    }

    // getVotingPower
    //
    // every memorial has bonus, SUM(unique memorial bonus) + 0.01 = voting power
    // This function is not commonly used, can get voting power from off-chain database
    pub fun getVotingPower(): UFix64{
      // the initial voting power is 0.01
      var votingPower = Memorials.initVotingPower
      if self.ownedNFTs.length == 0 {
        return votingPower
      }
      var uniqueMemorialBonusMap: {UInt64: UFix64} = {}
      for memorialID in self.ownedNFTs.keys{
        let memorial = self.borrowMemorial(id: memorialID)
        if memorial != nil{
          let activityID = memorial!.activityID
          if !uniqueMemorialBonusMap.keys.contains(activityID){
            uniqueMemorialBonusMap.insert(key: activityID, memorial!.bonus)
          }
        }
      }
      for bonus in uniqueMemorialBonusMap.values{
        votingPower = votingPower + bonus
      }
      return votingPower
    }
    
    // destructor
    destroy() {
        destroy self.ownedNFTs
    }

    // initializer
    init () {
        self.ownedNFTs <- {}
    }
  }

  
  // createEmptyCollection
  //
  // public function that anyone can call to create a new empty collection
  pub fun createEmptyCollection(): @NonFungibleToken.Collection {
    return <- create Collection()
  }

  // NFTMinter
  //
  // Resource that an admin or something similar would own to be
  // able to mint new NFTs
  pub resource NFTMinter {
    // mintNFT
    //
    // Mints a new NFT with information
    // and deposit it in the recipients collection using their collection reference
    // only can invoke by activityContract
    access(account) fun mintNFT(
      recipient: &{NonFungibleToken.CollectionPublic},
      seriesNumber: UInt64,
      circulatingCount: UInt64,
      activityID: UInt64,
      title: String,
      isPositive: Bool,
      bonus: UFix64,
      metadata: String
    ) {
      // new ID should supply + 1
      let toBeMintID = Memorials.totalSupply + 1
      // create new memorials NFT
      let newNFT <- create Memorials.NFT(
        initID: toBeMintID,
        seriesNumber: seriesNumber,
        circulatingCount: circulatingCount,
        activityID: activityID,
        title:title,
        isPositive: isPositive,
        bonus: bonus,
        metadata: metadata
      )
      // send to recipient
      recipient.deposit(token: <-newNFT)
      emit memorialMinted(
        version: Memorials.version,
        reciever: recipient.owner!.address,
        memorialId: toBeMintID,
        seriesNumber: seriesNumber,
        circulatingCount: circulatingCount,
        activityID: activityID,
        isPositive: isPositive,
        bonus: bonus
      )
      // update totalsupply
      Memorials.totalSupply = toBeMintID
    }
  }

  // fetch
  // Get a reference to a Memorials from an account's Collection, if available.
  // If an account does not have a Memorialss.Collection, panic.
  // If it has a collection but does not contain the itemID, return nil.
  // If it has a collection and that collection contains the itemID, return a reference to that.
  //
  pub fun fetch(_ from: Address, itemID: UInt64): &Memorials.NFT? {
    let collection = getAccount(from)
        .getCapability(Memorials.CollectionPublicPath)
        .borrow<&Memorials.Collection{Memorials.MemorialsCollectionPublic}>()
        ?? panic("Couldn't get collection")
    // We trust Memorialss.Collection.borowMemorials to get the correct itemID
    // (it checks it before returning it).
    return collection.borrowMemorial(id: itemID)
  }

  init() {
    // Set our named paths.
    // remove _x when mainnet deploy
    self.CollectionStoragePath = /storage/memorialssCollection_0
    self.CollectionPublicPath = /public/memorialssCollection_0
    self.MinterStoragePath = /storage/memorialssMinter_0

    // Initialize the total supply
    self.totalSupply = 0

    // Initialize voting power, use for caculate user's voting power, does not commonly use
    self.initVotingPower = 0.01

    // Create a Minter resource and save it to storage
    let minter <- create NFTMinter()
    self.account.save(<-minter, to: self.MinterStoragePath)

    // Initialize version
    self.version = 1
    emit ContractInitialized()
  }
}