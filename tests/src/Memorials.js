import { deployContractByName, executeScript, mintFlow, sendTransaction } from "flow-js-testing";
import { getAdminAddress } from "./common";

export const deployMemorials = async () => {
	const Admin = await getAdminAddress();
	await mintFlow(Admin, "1.0");
	await deployContractByName({ to: Admin, name: "NonFungibleToken" });

	const addressMap = {
		NonFungibleToken: Admin
	};
	return deployContractByName({ to: Admin, name: "Memorials", addressMap });
};

export const setupMemorialsOnAccount = async (account) => {
	const name = "Memorials/setup_account";
	const signers = [account];

	return sendTransaction({ name, signers });
};

export const getMemorialsSupply = async () => {
	const name = "Memorials/get_memorials_supply";
	return executeScript({ name });
};

export const getCollectionIds = async (address) => {
	const name = "Memorials/get_collection_ids";
	const args = [address]
	return executeScript({ name, args });
};

export const getCollectionLength = async (address) => {
	const name = "Memorials/get_colletion_length";
	const args = [address]
	return executeScript({ name, args });
};

export const getMemorial = async (address, itemID) => {
	const name = "Memorials/get_memorial";
	const args = [address, itemID]
	return executeScript({ name, args });
};