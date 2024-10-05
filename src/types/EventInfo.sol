// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/// @notice Struct to store event information
struct EventInfo {
    /// @notice Name of the event
    string name;
    /// @notice Metadata of the event
    string metadata;
    /// @notice Address of the event organizer
    address payable organizer;
    /// @notice Start date of the event
    uint256 startDate;
    /// @notice End date of the event
    uint256 endDate;
}
