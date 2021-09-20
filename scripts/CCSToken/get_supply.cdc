import CCSToken from "../../contracts/CCSToken.cdc"

pub fun main(): UFix64 {

    let supply = CCSToken.totalSupply

    log(supply)

    return supply
}
