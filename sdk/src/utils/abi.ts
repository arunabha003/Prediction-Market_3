import { AbiErrorFragment } from 'web3';

/* The web3-util-abi package is incorrect */
export const isAbiErrorFragment = (item: unknown): item is AbiErrorFragment =>
  typeof item === 'object' &&
  item != null &&
  Object.hasOwn(item, 'type') &&
  (item as { type: string }).type === 'error';
