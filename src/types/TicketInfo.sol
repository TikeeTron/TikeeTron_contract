// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/// @notice Struct to store ticket information
struct TicketInfo {
    /// @notice Type of the ticket
    string ticketType;
    /// @notice Price of the ticket
    uint256 ticketPrice;
    /// @notice Supply of the ticket
    uint256 ticketSupply;
}
