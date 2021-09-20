import { deployContractByName, executeScript, mintFlow, sendTransaction } from "flow-js-testing";
import { getAdminAddress } from "./common";
import { deployCCSToken } from "./CCSToken";

export const deployBallot = async () => {
	const Admin = await getAdminAddress();
	await mintFlow(Admin, "1.0");
	await deployCCSToken();

	const addressMap = {
		CCSToken: Admin,
	};

	return deployContractByName({ to: Admin, name: "BallotContract", addressMap });
};

export const setupBallotOnAccount = async (account) => {
	const name = "Ballot/setup_account";
	const signers = [account];
	return sendTransaction({ name, signers });
}

export const buyBallots = async (account, count) => {
	const name = "Ballot/buy_ballots";
	const args = [count]
	const signers = [account];
	return sendTransaction({ name, args, signers });
}

export const getHoldings = async (address) => {
	const name = "Ballot/get_holdings";
	const args = [address]
	return executeScript({ name, args });
};

export const getSoldAmount = async () => {
	const name = "Ballot/get_sold_amount";
	return executeScript({ name });
};

export const setPrice = async (price, account) => {
	const name = "Ballot/set_price";
	const args = [price]
	const signers = [account]
	return sendTransaction({ name, args, signers });
};

export const getPrice = async () => {
	const name = "Ballot/get_price";
	return executeScript({ name });
};