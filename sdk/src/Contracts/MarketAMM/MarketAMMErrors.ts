export const InsufficientLiquidityError = () => {
  return `The pool does not have enough liquidity to complete the trade.`;
};

const errors: { [CustomError: string]: (args: { [K in string]: unknown }) => string } = {
  InsufficientLiquidity: InsufficientLiquidityError,
};

export default errors;
