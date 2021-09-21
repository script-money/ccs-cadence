import ActivityContract from "../../contracts/ActivityContract.cdc"

pub fun main(): ActivityContract.RewardParameter {    
    return ActivityContract.getRewardParams()
}