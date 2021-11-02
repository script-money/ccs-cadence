import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import Memorials from "../../contracts/Memorials.cdc"

transaction {
    prepare(signer: AuthAccount) {
        // if the account doesn't already have a collection
        if signer.borrow<&Memorials.Collection>(from: Memorials.CollectionStoragePath) == nil {

            // create a new empty collection
            let collection <- Memorials.createEmptyCollection()
            
            // save it to the account
            signer.save(<-collection, to: Memorials.CollectionStoragePath)

            // create a public capability for the collection
            signer.link<&Memorials.Collection{NonFungibleToken.CollectionPublic, Memorials.MemorialsCollectionPublic}>(Memorials.CollectionPublicPath, target: Memorials.CollectionStoragePath)
        }
    }
}
