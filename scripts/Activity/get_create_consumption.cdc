import ActivityContract from "../../contracts/ActivityContract.cdc"

pub fun main(): UFix64 {    
    return ActivityContract.getCreateConsumption()
}