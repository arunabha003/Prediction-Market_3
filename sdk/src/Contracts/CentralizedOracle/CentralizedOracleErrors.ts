export const OutcomeNotResolvedYetError = () => {
  return 'Outcome not resolved yet';
};

const errors: { [CustomError: string]: (args: { [K in string]: unknown }) => string } = {
  OutcomeNotResolvedYet: OutcomeNotResolvedYetError,
};

export default errors;
