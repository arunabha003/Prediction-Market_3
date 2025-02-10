export const assertDeadline = (deadline: Date | bigint | number | string) => {
  if (typeof deadline === 'string') {
    deadline = Number(deadline);
  }

  if (deadline instanceof Date) {
    deadline = deadline.getTime() / 1000;
  }

  if (deadline < Date.now() / 1000) {
    throw new Error('Invalid Deadline: Deadline has passed');
  }
};

export const getTimestamp = (date: Date | bigint | number | string) => {
  if (typeof date === 'string') {
    date = Number(date);
  }

  if (date instanceof Date) {
    date = date.getTime() / 1000;
  }

  return date;
};
