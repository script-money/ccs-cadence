import { getAccountAddress } from "flow-js-testing";

const UFIX64_PRECISION = 8;

// UFix64 values shall be always passed as strings
export const toUFix64 = (value) => value.toFixed(UFIX64_PRECISION);

export const getAdminAddress = async () => getAccountAddress("Admin");

export const getEvent = (response, eventName) => response.events.find(event => event.type.includes(eventName))
export const getEvents = (response, eventName) => response.events.filter(event => event.type.includes(eventName))