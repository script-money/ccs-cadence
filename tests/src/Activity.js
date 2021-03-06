import { deployContractByName, executeScript, mintFlow, sendTransaction } from "flow-js-testing";
import { getAdminAddress, toUFix64 } from "./common";
import { deployBallot } from "./Ballot";
import { deployMemorials } from "./Memorials";

export const deployActivity = async () => {
	const Admin = await getAdminAddress();
	await mintFlow(Admin, "1.0");
	await deployBallot()
	await deployMemorials()

	const addressMap = {
		BallotContract: Admin,
		Memorials: Admin,
		NonFungibleToken: Admin,
	}

	return deployContractByName({ to: Admin, name: "ActivityContract", addressMap });
};

export const createActivity = async (account, title, metadata = "") => {
	const name = "Activity/create_activity";
	const args = [title, metadata]
	const signers = [account];

	return sendTransaction({ name, args, signers });
};
export const createAirdropActivity = async (account, title, toList, metadata = "") => {
	const name = "Activity/create_airdrop_activity";
	const args = [title, metadata, toList]
	const signers = [account];
	return sendTransaction({ name, args, signers });
};

export const getCreateConsumption = async () => {
	const name = "Activity/get_create_consumption";
	return executeScript({ name });
};

export const updateCreateConsumption = async (account, newPrice) => {
	const name = "Activity/update_consumption"
	const args = [newPrice]
	const signers = [account]
	return sendTransaction({ name, args, signers })
}

export const getActivityIds = async () => {
	const name = "Activity/get_activity_ids";
	return executeScript({ name });
};

export const getActivity = async (id) => {
	const name = "Activity/get_activity";
	const args = [id]
	return executeScript({ name, args });
};

export const vote = async (account, id, isUpVote) => {
	const name = "Activity/vote"
	const args = [id, isUpVote]
	const signers = [account]
	return sendTransaction({ name, args, signers })
}

export const closeActivity = async (account, id) => {
	const name = "Activity/close_activity"
	const args = [id]
	const signers = [account]
	return sendTransaction({ name, args, signers })
}

export const getRewardParams = async () => {
	const name = "Activity/get_reward_params";
	return executeScript({ name });
}

export const updateRewardParams = async (account, newParameter) => {
	const name = "Activity/update_reward_params";
	const args = [newParameter]
	const signers = [account]
	return sendTransaction({ name, args, signers })
}

export const createNewModerator = async (account, admin) => {
	const name = "Activity/create_new_admin";
	const signers = [account, admin]
	return sendTransaction({ name, signers })
}

export const batchMintMemorials = async (account, activityId, mintPositive, voteDict,
	startFrom = 1, isAirdrop = false, TotalCount = 0, bonus = toUFix64(1.0)) => {
	const name = "Activity/batch_mint_memorials";
	const args = [activityId, bonus, mintPositive, voteDict, startFrom, isAirdrop, TotalCount]
	const signers = [account]
	return sendTransaction({ name, args, signers })
};