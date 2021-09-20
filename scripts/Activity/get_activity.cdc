import ActivityContract from "../../contracts/ActivityContract.cdc"

pub struct ActivityItem {
  pub let title: String
  pub let id: UInt64
  pub let upVoteCount: Int
  pub let downVoteCount: Int
  pub let voteResult: {Address: Bool}
  pub var creator: Address
  pub let closed: Bool
  pub let metadata: String

  init(title: String, id: UInt64, upVoteCount:Int, downVoteCount:Int, voteResult:{Address: Bool}, creator:Address, closed: Bool, metadata: String) {
    self.title = title
    self.id = id
    self.upVoteCount = upVoteCount
    self.downVoteCount = downVoteCount
    self.voteResult = voteResult
    self.creator = creator
    self.closed = closed
    self.metadata = metadata
  }
}

pub fun main(_id: UInt64): ActivityItem? {    
  if let item = ActivityContract.getActivity(id: _id) {
    return ActivityItem(
      title: item.title,
      id: item.id,
      upVoteCount: item.upVoteCount,
      downVoteCount: item.downVoteCount,
      voteResult: item.voteResult,
      creator: item.creator,
      closed: item.closed,
      metadata: item.metadata
    )
  }
  return nil
}