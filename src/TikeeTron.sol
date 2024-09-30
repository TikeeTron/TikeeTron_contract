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
 * This contract allows organizers to create events, sell tickets as NFTs,
 * and manage ticket supplies. It includes features like fee calculation,
 * ticket buying, and event updates.
 */
contract TikeeTron is ERC721URIStorage, Ownable, ReentrancyGuard {
    // 3.00% fee with 2 decimals
    uint256 private immutable APP_FEE = 300;
    uint256 private _ticketId;
    uint256 private _eventId;

    mapping(uint256 eventId => EventInfo) public events;
    mapping(uint256 ticketId => uint256 eventId) public tickets;
    mapping(uint256 eventId => mapping(string ticketType => uint256 price)) public ticketPrices;
    mapping(uint256 eventId => mapping(string ticketType => uint256 supply)) public ticketSupplies;
    mapping(uint256 eventId => mapping(address owner => uint256 ticketCount)) public ticketsOwned;
    mapping(uint256 eventId => uint256 soldTickets) public ticketsSold;

    /**
     * @dev Emitted when a new event is created.
     */
    event EventCreated(
        uint256 indexed eventId, string name, string metadata, address indexed organizer, uint256 eventDate
    );

    /**
     * @dev Emitted when a ticket is bought.
     */
    event TicketBought(
        uint256 indexed ticketId, uint256 indexed eventId, string ticketType, address indexed buyer, uint256 ticketPrice
    );

    /**
     * @dev Emitted when an event is updated.
     */
    event EventUpdated(uint256 indexed eventId, string name, string metadata, uint256 date);

    /**
     * @dev Emitted when ticket supply is updated.
     */
    event TicketSupplyUpdated(uint256 indexed eventId, uint256 supply);

    /**
     * @dev Constructor that sets up the ERC721 token with name and symbol.
     */
    constructor() ERC721("TikeeTron", "TKT") Ownable(msg.sender) {}

    /**
     * @dev Creates a new event.
     * @param name The name of the event.
     * @param metadata The metadata of the event.
     * @param date The date of the event.
     * @param totalTickets The total number of tickets for the event.
     * @param ticketInfos An array of TicketInfo structs containing ticket details.
     */
    function createEvent(
        string calldata name,
        string calldata metadata,
        uint256 date,
        uint256 totalTickets,
        TicketInfo[] calldata ticketInfos
    ) external beforeCreateEvent(ticketInfos, totalTickets) {
        require(date > block.timestamp, "Event date must be in the future");
        events[_eventId] = EventInfo(name, metadata, payable(msg.sender), date, totalTickets);
        mapTickets(ticketInfos, totalTickets);

        emit EventCreated(_eventId, name, metadata, msg.sender, date);
        _eventId++;
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
        uint256 ticketPrice = ticketPrices[eventId][ticketType];
        require(msg.value >= ticketPrice, "Insufficient funds");

        _ticketId++;
        _safeMint(msg.sender, _ticketId);
        _setTokenURI(_ticketId, metadata);
        ticketSupplies[eventId][ticketType]--;
        ticketsSold[eventId]++;
        ticketsOwned[eventId][msg.sender]++;
        tickets[_ticketId] = eventId;

        // 3% fee
        uint256 fee = calculateFee(ticketPrices[eventId][ticketType]);
        uint256 amount = ticketPrices[eventId][ticketType] - fee;

        (bool success,) = events[eventId].organizer.call{value: amount}("");
        require(success, "Transfer to organizer failed");
        (success,) = payable(owner()).call{value: fee}("");
        require(success, "Transfer fee failed");

        // Refund any excess funds
        if (msg.value > ticketPrice) {
            (bool successRefund,) = payable(msg.sender).call{value: msg.value - ticketPrice}("");
            require(successRefund, "Refund failed");
        }

        emit TicketBought(_ticketId, eventId, ticketType, msg.sender, ticketPrices[eventId][ticketType]);
    }

    /**
     * @dev Allows the organizer to update event details.
     * @param eventId The ID of the event to update.
     * @param name The new name of the event.
     * @param metadata The new metadata for the event.
     * @param date The new date for the event.
     */
    function updateEvent(uint256 eventId, string memory name, string memory metadata, uint256 date)
        external
        onlyOrganizer(eventId)
    {
        require(events[eventId].date > block.timestamp, "Event has already started");
        require(date > block.timestamp, "Event date must be in the future");

        events[eventId].name = name;
        events[eventId].metadata = metadata;
        events[eventId].date = date;

        emit EventUpdated(eventId, name, metadata, date);
    }

    /**
     * @dev Allows the organizer to update ticket supplies for an event.
     * @param eventId The ID of the event.
     * @param ticketInfos An array of TicketInfo structs with updated ticket details.
     * @param totalTickets The new total number of tickets.
     */
    function updateTicketSupplies(uint256 eventId, TicketInfo[] memory ticketInfos, uint256 totalTickets)
        external
        onlyOrganizer(eventId)
        beforeCreateEvent(ticketInfos, totalTickets)
    {
        require(events[eventId].date > block.timestamp, "Event has already started");
        require(totalTickets >= ticketsSold[eventId], "Total tickets cannot be less than tickets sold");

        updateTickets(eventId, ticketInfos, totalTickets - ticketsSold[eventId]);
        events[eventId].totalTickets = totalTickets;

        emit TicketSupplyUpdated(eventId, totalTickets);
    }

    /**
     * @dev Returns the total number of tickets available for an event.
     * @param eventId The ID of the event.
     * @return The total number of tickets available.
     */
    function getAvailableTickets(uint256 eventId) public view returns (uint256) {
        return events[eventId].totalTickets - ticketsSold[eventId];
    }

    /**
     * @dev Returns the number of available tickets for a specific type.
     * @param eventId The ID of the event.
     * @param ticketType The type of ticket.
     * @return The number of available tickets for the type.
     */
    function getAvailableTicketsByType(uint256 eventId, string memory ticketType) public view returns (uint256) {
        return ticketSupplies[eventId][ticketType];
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
     * @param totalTickets The total number of tickets for the event.
     */
    function mapTickets(TicketInfo[] memory ticketInfos, uint256 totalTickets) private {
        uint256 totalTicketSupply = 0;
        for (uint256 i = 0; i < ticketInfos.length; i++) {
            uint256 ticketSupply = ticketInfos[i].ticketSupply;
            uint256 ticketPrice = ticketInfos[i].ticketPrice;

            require(ticketSupply > 0, "Ticket supply each type must be greater than 0");
            totalTicketSupply += ticketSupply;
            ticketPrices[_eventId][ticketInfos[i].ticketType] = ticketPrice;
            ticketSupplies[_eventId][ticketInfos[i].ticketType] = ticketSupply;
        }
        require(totalTickets == totalTicketSupply, "Total tickets must be equal to the sum of ticket supplies");
    }

    /**
     * @dev Internal function to update ticket information for an existing event.
     * @param eventId The ID of the event.
     * @param ticketInfos An array of TicketInfo structs with updated information.
     * @param availableTickets The number of available tickets.
     */
    function updateTickets(uint256 eventId, TicketInfo[] memory ticketInfos, uint256 availableTickets) private {
        uint256 totalTicketSupply = 0;
        for (uint256 i = 0; i < ticketInfos.length; i++) {
            totalTicketSupply += ticketInfos[i].ticketSupply;
            ticketPrices[eventId][ticketInfos[i].ticketType] = ticketInfos[i].ticketPrice;
            ticketSupplies[eventId][ticketInfos[i].ticketType] = ticketInfos[i].ticketSupply;
        }
        require(availableTickets == totalTicketSupply, "Total tickets must be equal to the sum of ticket supplies");
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
     * @dev Modifier to restrict function access to the event organizer.
     * @param eventId The ID of the event.
     */
    modifier onlyOrganizer(uint256 eventId) {
        require(events[eventId].organizer == msg.sender, "Only the organizer can call this function");
        _;
    }

    /**
     * @dev Modifier to validate inputs before creating an event.
     * @param ticketInfos An array of TicketInfo structs.
     * @param totalTickets The total number of tickets.
     */
    modifier beforeCreateEvent(TicketInfo[] memory ticketInfos, uint256 totalTickets) {
        require(totalTickets > 0, "Total tickets must be greater than 0");
        require(ticketInfos.length > 0, "Ticket types must be greater than 0");
        _;
    }

    /**
     * @dev Modifier to validate inputs before buying a ticket.
     * @param eventId The ID of the event.
     * @param ticketType The type of ticket being purchased.
     */
    modifier beforeBuyTicket(uint256 eventId, string memory ticketType) {
        require(events[eventId].date > block.timestamp, "Event has already started");
        require(ticketSupplies[eventId][ticketType] > 0, "Ticket type does not exist");
        _;
    }
}
