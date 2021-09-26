import FungibleToken from "./FungibleToken.cdc"

pub contract CCSToken: FungibleToken {

    pub var totalSupply: UFix64

    pub event TokensInitialized(initialSupply: UFix64)
    pub event TokensWithdrawn(amount: UFix64, from: Address?)
    pub event TokensDeposited(amount: UFix64, to: Address?)
    pub event TokensMinted(amount: UFix64)
    pub event TokensBurned(amount: UFix64)
    pub event MinterCreated(allowedAmount: UFix64)
    pub event TokenAirdrop(receiver: Address, amount: UFix64)

    pub let VaultStoragePath: StoragePath
    pub let ReceiverPublicPath: PublicPath
    pub let BalancePublicPath: PublicPath
    pub let AdminStoragePath: StoragePath

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

    pub fun createEmptyVault(): @Vault {
      return <-create Vault(balance: 0.0)
    }

    pub resource Administrator {
      pub fun createNewMinter(allowedAmount: UFix64): @Minter {
          emit MinterCreated(allowedAmount: allowedAmount)
          return <-create Minter(allowedAmount: allowedAmount)
      }

      pub fun createAirdrop(addressAmountMap: {Address: UFix64}){
        for address in addressAmountMap.keys{
          let receiverRef = getAccount(address).getCapability(CCSToken.ReceiverPublicPath)
          .borrow<&{FungibleToken.Receiver}>()?? panic("Unable to borrow receiver reference")

          let amount = addressAmountMap[address]!
          let minter <- self.createNewMinter(allowedAmount: amount)
          let mintedVault <- minter.mintTokens(amount: amount)
          receiverRef.deposit(from: <-mintedVault)
          emit TokenAirdrop(receiver: address, amount: amount)
          destroy minter
        }
      }
    }

    pub resource Minter {
      pub var allowedAmount: UFix64

      pub fun mintTokens(amount: UFix64): @CCSToken.Vault {
        pre {
          amount > 0.0: "Amount minted must be greater than zero"
          amount <= self.allowedAmount: "Amount minted must be less than the allowed amount"
        }
        CCSToken.totalSupply = CCSToken.totalSupply + amount
        self.allowedAmount = self.allowedAmount - amount
        emit TokensMinted(amount: amount)
        return <-create Vault(balance: amount)
      }

      init(allowedAmount: UFix64) {
        self.allowedAmount = allowedAmount
      }
    }
  

    init() {
      self.VaultStoragePath = /storage/CCSVault
      self.ReceiverPublicPath = /public/CCSReceiver
      self.BalancePublicPath = /public/CCSBalance
      self.AdminStoragePath = /storage/CCSAdmin

      self.totalSupply = 0.0

      let admin <- create Administrator()
      self.account.save(<-admin, to: self.AdminStoragePath)

      emit TokensInitialized(initialSupply: self.totalSupply)
    }
}
 