import FungibleToken from "../../contracts/FungibleToken.cdc"
import CCSToken from "../../contracts/CCSToken.cdc"

transaction {

    prepare(signer: AuthAccount) {

        if signer.borrow<&CCSToken.Vault>(from: CCSToken.VaultStoragePath) == nil {
            signer.save(<-CCSToken.createEmptyVault(), to: CCSToken.VaultStoragePath)

            signer.link<&CCSToken.Vault{FungibleToken.Receiver}>(
                CCSToken.ReceiverPublicPath,
                target: CCSToken.VaultStoragePath
            )

            signer.link<&CCSToken.Vault{FungibleToken.Balance}>(
                CCSToken.BalancePublicPath,
                target: CCSToken.VaultStoragePath
            )
        }
    }
}
