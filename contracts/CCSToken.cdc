import FungibleToken from "./FungibleToken.cdc"

pub contract CCSToken: FungibleToken {
    // Total supply of CCSToken resource in existence, it's FungibleToken
    pub var totalSupply: UFix64

    // event when CCSToken contract is deployed
    pub event TokensInitialized(initialSupply: UFix64)

    // The event that is emitted when tokens are withdrawn from a Vault
    pub event TokensWithdrawn(amount: UFix64, from: Address?)

    // The event that is emitted when tokens are deposited to a Vault
    pub event TokensDeposited(amount: UFix64, to: Address?)

    // The event that is emitted when tokens are destroyed
    pub event TokensBurned(amount: UFix64)

    // The event that is emitted when a new minter resource is created
    pub event MinterCreated(allowedAmount: UFix64)

    // The event that is emitted when create airdrop tokens
    pub event TokenAirdrop(receiver: Address, amount: UFix64)

    // Named paths
    pub let VaultStoragePath: StoragePath
    pub let ReceiverPublicPath: PublicPath
    pub let BalancePublicPath: PublicPath
    pub let AdminStoragePath: StoragePath

    // Vault
    //
    // Each user stores an instance of only the Vault in their storage
    // The functions in the Vault and governed by the pre and post conditions
    // in FungibleToken when they are called.
    // The checks happen at runtime whenever a function is called.
    //
    // Resources can only be created in the context of the contract that they
    // are defined in, so there is no way for a malicious user to create Vaults
    // out of thin air. A special Minter resource needs to be defined to mint
    // new tokens.
    //
    pub resource Vault: FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance {
      pub var balance: UFix64

      init(balance: UFix64) {
        self.balance = balance
      }

      pub fun withdraw(amount: UFix64): @FungibleToken.Vault {
        self.balance = self.balance - amount
        emit TokensWithdrawn(amount: amount, from: self.owner?.address)
        return <-create Vault(balance: amount)
      }

      pub fun deposit(from: @FungibleToken.Vault) {
        let vault <- from as! @CCSToken.Vault
        self.balance = self.balance + vault.balance
        emit TokensDeposited(amount: vault.balance, to: self.owner?.address)
        vault.balance = 0.0
        destroy vault
      }

      destroy() {
        CCSToken.totalSupply = CCSToken.totalSupply - self.balance
        if(self.balance > 0.0) {
          emit TokensBurned(amount: self.balance)
        }
      }
    }

    // createEmptyVault
    //
    // Function that creates a new Vault with a balance of zero
    // and returns it to the calling context. A user must call this function
    // and store the returned Vault in their storage in order to allow their
    // account to be able to receive deposits of this token type.
    //
    pub fun createEmptyVault(): @Vault {
      return <-create Vault(balance: 0.0)
    }

    pub resource Administrator {
      // createAirdrop
      //
      // Function that directly create vault and mint tokens to a receiver
      // can airdrop to multiple receivers once
      pub fun createAirdrop(addressAmountMap: {Address: UFix64}){
        for address in addressAmountMap.keys{
          let receiverRef = getAccount(address).getCapability(CCSToken.ReceiverPublicPath)
          .borrow<&{FungibleToken.Receiver}>()?? panic("Unable to borrow receiver reference")

          let amount = addressAmountMap[address]!
          CCSToken.totalSupply = CCSToken.totalSupply + amount
          receiverRef.deposit(from: <-create Vault(balance: amount))
          emit TokenAirdrop(receiver: address, amount: amount)
        }
      }
    }

    init() {
      // Set our named paths.
      // remove _x when mainnet deploy
      self.VaultStoragePath = /storage/CCSVault_0
      self.ReceiverPublicPath = /public/CCSReceiver_0
      self.BalancePublicPath = /public/CCSBalance_0
      self.AdminStoragePath = /storage/CCSAdmin_0

      self.totalSupply = 0.0

      let admin <- create Administrator()
      self.account.save(<-admin, to: self.AdminStoragePath)

      emit TokensInitialized(initialSupply: self.totalSupply)
    }
}
 