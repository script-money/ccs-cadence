import Memorials from "../../contracts/Memorials.cdc"

// This scripts returns the number of Memorials currently in existence.

pub fun main(): UInt64 {    
    return Memorials.totalSupply
}
