import type { FormattedDate, FormattedETH } from '../types';

import { utils } from 'web3';

export const formatETH = (wei: number | bigint | string): FormattedETH => {
  wei = BigInt(`${wei}`);

  const weiBigInt = wei;
  const gweiBigInt = utils.fromWei(wei.toString(), 'gwei');
  const ethBigInt = utils.fromWei(wei.toString(), 'ether');

  return {
    wei: weiBigInt.toString(),
    gwei: gweiBigInt.toString(),
    eth: ethBigInt.toString(),
    weiBigInt,
  };
};

export const formatDate = (date: Date): FormattedDate => {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  const hours = String(date.getHours()).padStart(2, '0');
  const minutes = String(date.getMinutes()).padStart(2, '0');
  const seconds = String(date.getSeconds()).padStart(2, '0');

  const formattedDate = `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;

  return {
    date,
    timestampMillis: date.getTime(),
    timestamp: Math.floor(date.getTime() / 1000),
    formattedDate,
  };
};
