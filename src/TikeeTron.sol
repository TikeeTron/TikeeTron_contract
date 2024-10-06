// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC721, ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {EventInfo} from "./types/EventInfo.sol";
import {TicketInfo} from "./types/TicketInfo.sol";

/**
 * @title TikeeTron
 * @dev A contract for managing event tickets as NFTs.
 *
 * The contract allows event organizers to create events and sell tickets for those events.
 */
contract TikeeTron is ERC721URIStorage, Ownable, ReentrancyGuard {
    // 3.00% fee with 2 decimals
    uint256 private immutable APP_FEE = 300;
    uint256 public _ticketId;
    uint256 public _eventId;

    mapping(uint256 eventId => EventInfo) public events;
    mapping(uint256 ticketId => uint256 eventId) public tickets;
    mapping(uint256 eventId => mapping(string ticketType => TicketInfo)) public ticketInfo;
    mapping(uint256 eventId => uint256 soldTickets) public ticketsSold;
    mapping(uint256 ticketId => bool isTicketUsed) public usedTickets;

    /**
     * @dev Emitted when a new event is created.
     */
    event EventCreated(
        uint256 indexed eventId,
        string name,
        string metadata,
        address indexed organizer,
        uint256 startDate,
        uint256 endDate
    );

    /**
     * @dev Emitted when a ticket is bought.
     */
    event TicketBought(
        uint256 indexed ticketId, uint256 indexed eventId, string ticketType, address indexed buyer, uint256 ticketPrice
    );

    /**
     * @dev Emitted when a ticket is used.
     */
    event TicketUsed(uint256 indexed ticketId, uint256 indexed eventId, address indexed organizer);

    /**
     * @dev Constructor that sets up the ERC721 token with name and symbol.
     */
    constructor() ERC721("TikeeTron", "TKT") Ownable(msg.sender) {}

    /**
     * @dev Creates a new event.
     * @param name The name of the event.
     * @param metadata The metadata of the event.
     * @param startDate The start date of the event.
     * @param endDate The end date of the event.
     * @param ticketInfos An array of TicketInfo structs containing ticket details.
     */
    function createEvent(
        string calldata name,
        string calldata metadata,
        uint256 startDate,
        uint256 endDate,
        TicketInfo[] calldata ticketInfos
    ) external beforeCreateEvent(ticketInfos) {
        require(startDate > block.timestamp, "Event start date must be in the future");
        require(endDate > startDate, "Event end date must be after start date");

        events[_eventId] = EventInfo(name, metadata, payable(msg.sender), startDate, endDate);
        mapTickets(ticketInfos);

        emit EventCreated(_eventId, name, metadata, msg.sender, startDate, endDate);
        _eventId++;
    }

    /**
     * @dev Get event details.
     * @param eventId The ID of the event.
     */
    function getEvent(uint256 eventId) public view returns (EventInfo memory) {
        return events[eventId];
    }

    /**
     * @dev Allows a user to buy a ticket for an event.
     * @param eventId The ID of the event.
     * @param metadata The metadata for the ticket NFT.
     * @param ticketType The type of ticket being purchased.
     */
    function buyTicket(uint256 eventId, string memory metadata, string memory ticketType)
        external
        payable
        beforeBuyTicket(eventId, ticketType)
        nonReentrant
    {
        TicketInfo storage ticketDetail = ticketInfo[eventId][ticketType];

        _ticketId++;
        _safeMint(msg.sender, _ticketId);
        _setTokenURI(_ticketId, metadata);
        ticketDetail.ticketSupply--;
        ticketsSold[eventId]++;
        tickets[_ticketId] = eventId;

        // 3% fee
        uint256 fee = calculateFee(ticketDetail.ticketPrice);
        uint256 amount = ticketDetail.ticketPrice - fee;

        (bool success,) = events[eventId].organizer.call{value: amount}("");
        require(success, "Transfer to organizer failed");
        (success,) = payable(owner()).call{value: fee}("");
        require(success, "Transfer fee failed");

        emit TicketBought(_ticketId, eventId, ticketType, msg.sender, ticketDetail.ticketPrice);
    }

    /**
     * @dev Allows the organizer to use a ticket.
     * @param ticketId The ID of the ticket.
     */
    function useTicket(uint256 ticketId) public onlyOrganizer(getEventId(ticketId)) {
        require(!usedTickets[ticketId], "Ticket has already been used");

        usedTickets[ticketId] = true;

        emit TicketUsed(ticketId, getEventId(ticketId), msg.sender);
    }

    /**
     * @dev Returns whether a ticket has been used.
     * @param ticketId The ID of the ticket.
     * @return A boolean indicating whether the ticket has been used.
     */
    function isTicketUsed(uint256 ticketId) public view returns (bool) {
        return usedTickets[ticketId];
    }

    /**
     * @dev Returns the event ID for a given ticket ID.
     * @param ticketId The ID of the ticket.
     * @return The ID of the event.
     */
    function getEventId(uint256 ticketId) public view returns (uint256) {
        return tickets[ticketId];
    }

    /**
     * @dev Returns the number of available tickets for a specific type.
     * @param eventId The ID of the event.
     * @param ticketType The type of ticket.
     * @return The number of available tickets for the type.
     */
    function getAvailableTicketsByType(uint256 eventId, string memory ticketType) public view returns (uint256) {
        return ticketInfo[eventId][ticketType].ticketSupply;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view override(ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view override(ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    /**
     * @dev Internal function to map ticket information for a new event.
     * @param ticketInfos An array of TicketInfo structs.
     */
    function mapTickets(TicketInfo[] memory ticketInfos) private {
        for (uint256 i = 0; i < ticketInfos.length; i++) {
            require(ticketInfos[i].ticketSupply > 0, "Ticket supply must be greater than 0");
            require(ticketInfos[i].ticketStartDate > block.timestamp, "Ticket start date must be in the future");
            require(
                ticketInfos[i].ticketEndDate > ticketInfos[i].ticketStartDate,
                "Ticket end date must be after start date"
            );

            ticketInfo[_eventId][ticketInfos[i].ticketType] = ticketInfos[i];
        }
    }

    /**
     * @dev Calculates the fee for a given amount.
     * @param amount The amount to calculate the fee for.
     * @return The calculated fee.
     */
    function calculateFee(uint256 amount) private pure returns (uint256) {
        return (amount * APP_FEE) / 10000;
    }

    /**
     * @dev Modifier to restrict access to the event organizer.
     * @param eventId The ID of the event.
     */
    modifier onlyOrganizer(uint256 eventId) {
        require(events[eventId].organizer == msg.sender, "Only the event organizer can perform this action");
        _;
    }

    /**
     * @dev Modifier to validate inputs before creating an event.
     * @param ticketInfos An array of TicketInfo structs.
     */
    modifier beforeCreateEvent(TicketInfo[] memory ticketInfos) {
        require(ticketInfos.length > 0, "Ticket types must be greater than 0");
        _;
    }

    /**
     * @dev Modifier to validate inputs before buying a ticket.
     * @param eventId The ID of the event.
     * @param ticketType The type of ticket being purchased.
     */
    modifier beforeBuyTicket(uint256 eventId, string memory ticketType) {
        TicketInfo memory ticketDetail = ticketInfo[eventId][ticketType];
        require(ticketDetail.ticketStartDate < block.timestamp, "Ticket sales have not started");
        require(ticketDetail.ticketEndDate > block.timestamp, "Ticket sales have ended");
        require(ticketDetail.ticketSupply > 0, "Ticket supplies are exhausted");
        require(ticketDetail.ticketPrice == msg.value, "Incorrect ticket price");
        _;
    }
}
