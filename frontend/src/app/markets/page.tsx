'use client';

import {useEffect, useState} from 'react';
import {useRouter} from 'next/navigation';
import {betOnMarket, getMarkets} from '@/lib/api';

export default function Markets() {
	const [markets, setMarkets] = useState([]);
	const [loading, setLoading] = useState(true);
	const [betAmounts, setBetAmounts] = useState<{ [key: string]: string }>({});
	const router = useRouter();

	useEffect(() => {
		const fetchMarkets = async () => {
			try {
				const data = await getMarkets();
				setMarkets(data.markets);
			} catch (error) {
				console.error('Failed to fetch markets:', error);
			} finally {
				setLoading(false);
			}
		};

		fetchMarkets();
	}, []);

	if (loading) {
		return <div>Loading markets...</div>;
	}

	const handleBetOnMarketClick = async (marketAddress: string, amount: string) => {
		const amountInEth = parseFloat(amount);
		if (isNaN(amountInEth) || amountInEth <= 0) {
			alert('Please enter a valid amount in ETH');
			return;
		}

		try {
			const betResponse = await betOnMarket({
				"chainId": 11155111,
				"amount": amountInEth,
				"marketAddress": marketAddress
			});
			console.log('Bet response:', betResponse);
 			window.location.reload()
			return betResponse;
		} catch (error) {
			alert('Failed to place bet')
			console.error('Failed to place bet:', error);
			return;
		} finally {
			 window.location.reload()
		}
	};

	const handleBetAmountChange = (marketAddress: string, amount: string) => {
		setBetAmounts((prev) => ({...prev, [marketAddress]: amount}));
	};

	return (
		<div className="max-w-7xl mx-auto py-12 px-4 sm:px-6 lg:px-8">
			<h1 className="text-3xl font-bold text-gray-900">Prediction Markets</h1>
			<button onClick={() => router.push('/markets/create')}
					className="mb-4 px-4 py-2 bg-blue-500 text-white rounded">
				Create Market
			</button>
			<div className="mt-6 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
				{markets.map((market: any) => (
					<div
						key={market.marketAddress}
						className="bg-white overflow-hidden shadow rounded-lg flex"
					>
						<div className="px-4 py-5 sm:p-6 flex-1">
							<h3 className="text-lg font-medium text-gray-900">
								{market.marketName}
							</h3>
							<div className="mt-2">
								<p className="text-sm text-gray-500">
									Chain: Sepolia
								</p>
								<p className="text-sm text-gray-500">
									Outcome Count: {market.outcomeCount}
								</p>
							</div>
						</div>
						<div className="px-4 py-5 sm:p-6 flex-1 flex items-center justify-center">
							{market.userBets && market.userBets !== '0' ? (
								<div>
									<p className="text-sm text-gray-500">Your Bets:</p>
									<p className="text-lg font-medium text-gray-900">{market.userBets}</p>
								</div>
							) : (
								<div>
									<input
										type="number"
										value={betAmounts[market.marketAddress] || ''}
										onChange={(e) => handleBetAmountChange(market.marketAddress, e.target.value)}
										placeholder="Amount in ETH"
										className="mb-2 px-4 py-2 border rounded max-w-44"
									/>
									<button
										onClick={() => handleBetOnMarketClick(market.marketAddress, betAmounts[market.marketAddress] || '')}
										className="px-4 py-2 bg-green-500 text-white rounded"
									>
										Place Bet
									</button>
								</div>
							)}
						</div>
					</div>
				))}
			</div>
		</div>
	);
}