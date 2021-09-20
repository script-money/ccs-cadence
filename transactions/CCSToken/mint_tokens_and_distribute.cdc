import FungibleToken from "../../contracts/FungibleToken.cdc"
import CCSToken from "../../contracts/CCSToken.cdc"

transaction(addressAmountMap: {Address: UFix64}) {

    let adminRef: &CCSToken.Administrator

    prepare(signer: AuthAccount) {
      self.adminRef = signer.borrow<&CCSToken.Administrator>(from: CCSToken.AdminStoragePath)
			?? panic("Could not borrow admin's resource in CCSToken!")
    }

    execute{
      for address in addressAmountMap.keys{
        let receiverRef = getAccount(address).getCapability(CCSToken.ReceiverPublicPath)
        .borrow<&{FungibleToken.Receiver}>()?? panic("Unable to borrow receiver reference")

        let amount = addressAmountMap[address]!
        let minter <- self.adminRef.createNewMinter(allowedAmount: amount)
        let mintedVault <- minter.mintTokens(amount: amount)
        receiverRef.deposit(from: <-mintedVault)
        destroy minter
      }
    }
}