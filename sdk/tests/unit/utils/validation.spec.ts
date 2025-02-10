import { assertDeadline } from '../../../src/utils/validation';

describe('Validation', () => {
  describe('assertDeadline', () => {
    it('should throw an error if deadline is less than the current time', () => {
      expect(() => {
        assertDeadline(Date.now() / 1000 - 1);
      }).toThrowError('Invalid Deadline: Deadline has passed');
    });

    it('should not throw an error if deadline is a number', () => {
      expect(() => {
        assertDeadline(Date.now() / 1000 + 1);
      }).not.toThrow();
    });

    it('should not throw an error if deadline is a bigint', () => {
      expect(() => {
        assertDeadline(BigInt(Math.round(Date.now() / 1000 + 1).toString()));
      }).not.toThrow();
    });
  });
});
