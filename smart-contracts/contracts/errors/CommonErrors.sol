// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

///@notice This error is thrown when the array index is out of bounds
error IndexOutOfBounds();

/// @notice This error is returned when a variable is set to the zero address when it should not be
error ZeroAddress();

/// @notice This error is thrown when the provided amount doesn't match the msg.value
error AmountMismatch(uint256 expected, uint256 actual);

/// @notice This error is thrown when the deadline for the transaction has passed
error DeadlinePassed();

/// @notice This error is thrown when the transfer of ETH fails
error TransferFailed();
