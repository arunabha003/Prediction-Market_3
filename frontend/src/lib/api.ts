import axios from 'axios';

const api = axios.create({
	baseURL: process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3500/api/',
});

// const chainContext = {
// 	chainId: 11155111,
// 	chainName: 'Sepolia',
// 	rpcUrl: 'https://rpc.sepolia.org'
// };

export const getMarkets = async () => {
	const {data} = await api.get(`markets/?chainId=11155111`);
	return data;
};


export const createMarket = async (marketData: unknown) => {
	const {data} = await api.post('markets/create-market/?chainId=11155111', marketData);
	return data;
};

export const betOnMarket = async (marketData: unknown) => {
	const {data} = await api.post('markets/bet/?chainId=11155111', marketData);
	return data;
};

export const getUserPositions = async (userId: string) => {
	const {data} = await api.get(`/users/${userId}/positions`);
	return data;
};