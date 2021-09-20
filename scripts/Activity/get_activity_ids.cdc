import ActivityContract from "../../contracts/ActivityContract.cdc"

pub fun main(): [UInt64] {    
    return ActivityContract.getIDs()
}
