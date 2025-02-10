import { ethers } from 'ethers';

export class Web3Service {
  private provider: ethers.Provider | null = null;
  private signer: ethers.Signer | null = null;

  async connect(chainId: number = 1) {
    if (typeof window === 'undefined' || !window.ethereum) {
      throw new Error('Please install MetaMask');
    }

    const provider = new ethers.BrowserProvider(window.ethereum);
    const signer = await provider.getSigner();
    
    this.provider = provider;
    this.signer = signer;
    
    return { provider, signer };
  }

  async createMarket(contractAddress: string, marketData: un) {
    if (!this.signer) throw new Error('Please connect wallet first');
    
    // Implementation would depend on your smart contract ABI
    // This is just a placeholder
    const contract = new ethers.Contract(
      contractAddress,
      ['function createMarket(string title, string[] outcomes, uint256 endDate)'],
      this.signer
    );

    return await contract.createMarket(
      marketData.title,
      marketData.outcomes,
      marketData.endDate
    );
  }
}

export const web3Service = new Web3Service();