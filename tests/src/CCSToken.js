import { deployContractByName, executeScript, mintFlow, sendTransaction } from "flow-js-testing";
import { getAdminAddress } from "./common";

export const deployCCSToken = async () => {
	const Admin = await getAdminAddress();
	await mintFlow(Admin, "1.0");

	return deployContractByName({ to: Admin, name: "CCSToken" });
};

export const getCCSTokenSupply = async () => {
	const name = "CCSToken/get_supply";
	return executeScript({ name });
};

export const mintTokenAndDistribute = async (addressAmountMap) => {
	const Admin = await getAdminAddress();

	const name = "CCSToken/mint_tokens_and_distribute";
	const args = [addressAmountMap];
	const signers = [Admin];

	return sendTransaction({ name, args, signers });
}

export const setupCCSTokenOnAccount = async (account) => {
	const name = "CCSToken/setup_account";
	const signers = [account];

	return sendTransaction({ name, signers });
};

export const getCCSTokenBalance = async (account) => {
	const name = "CCSToken/get_balance";
	const args = [account];

	return executeScript({ name, args });
};