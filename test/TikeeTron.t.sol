// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import {TikeeTron} from "../src/TikeeTron.sol";
import {TicketInfo} from "../src/types/TicketInfo.sol";

contract TikeeTronTest is Test {
    TikeeTron private tikeeTron;
    address private owner = address(1);
    address private organizer = address(2);
    address private user1 = address(3);
    address private user2 = address(4);
    // 3.00% fee with 2 decimals
    uint256 private constant FEE_PERCENTAGE = 300;

    function setUp() public {
        vm.startPrank(owner);
        tikeeTron = new TikeeTron();
        vm.stopPrank();

        vm.deal(organizer, 100 ether);
        vm.deal(user1, 100 ether);
    }

    function test_createEvent() public {
        string memory name = "Test Event";
        string memory metadata = "This is a test event";
        uint256 date = block.timestamp + 1 days;
        uint256 totalTickets = 100;
        TicketInfo memory ticketInfo = TicketInfo({ticketType: "VIP", ticketPrice: 100 ether, ticketSupply: 100});
        TicketInfo[] memory ticketInfos = new TicketInfo[](1);
        ticketInfos[0] = ticketInfo;

        vm.prank(organizer);
        tikeeTron.createEvent(name, metadata, date, totalTickets, ticketInfos);
        vm.stopPrank();

        (
            string memory eventName,
            string memory eventMetadata,
            address eventOrganizer,
            uint256 eventDate,
            uint256 eventTotalTickets
        ) = tikeeTron.events(0);
        assertEq(eventName, name);
        assertEq(eventMetadata, metadata);
        assertEq(eventOrganizer, organizer);
        assertEq(eventDate, date);
        assertEq(eventTotalTickets, totalTickets);
        assertEq(tikeeTron.ticketPrices(0, "VIP"), 100 ether);
        assertEq(tikeeTron.ticketSupplies(0, "VIP"), 100);
    }

    function test_createEvent_emitsEvent() public {
        string memory name = "Test Event";
        string memory metadata = "This is a test event";
        uint256 date = block.timestamp + 1 days;
        uint256 totalTickets = 100;
        TicketInfo memory ticketInfo = TicketInfo({ticketType: "VIP", ticketPrice: 100 ether, ticketSupply: 100});
        TicketInfo[] memory ticketInfos = new TicketInfo[](1);
        ticketInfos[0] = ticketInfo;

        vm.expectEmit(true, true, true, true);
        emit TikeeTron.EventCreated(0, name, metadata, organizer, date);

        vm.prank(organizer);
        tikeeTron.createEvent(name, metadata, date, totalTickets, ticketInfos);
        vm.stopPrank();
    }

    function test_createEvent_RevertIf_DateIsInPast() public {
        string memory name = "Test Event";
        string memory metadata = "This is a test event";
        vm.warp(block.timestamp + 1 days);
        uint256 date = block.timestamp - 1 days;
        uint256 totalTickets = 100;
        TicketInfo memory ticketInfo = TicketInfo({ticketType: "VIP", ticketPrice: 100 ether, ticketSupply: 100});
        TicketInfo[] memory ticketInfos = new TicketInfo[](1);
        ticketInfos[0] = ticketInfo;

        vm.expectRevert("Event date must be in the future");
        tikeeTron.createEvent(name, metadata, date, totalTickets, ticketInfos);
    }

    function test_createEvent_RevertIf_TicketInfosIsEmpty() public {
        string memory name = "Test Event";
        string memory metadata = "This is a test event";
        uint256 date = block.timestamp + 1 days;
        uint256 totalTickets = 100;
        TicketInfo[] memory ticketInfos = new TicketInfo[](0);

        vm.expectRevert("Ticket types must be greater than 0");
        tikeeTron.createEvent(name, metadata, date, totalTickets, ticketInfos);
    }

    function test_createEvent_RevertIf_TicketSupplyEachTypeIsZero() public {
        string memory name = "Test Event";
        string memory metadata = "This is a test event";
        uint256 date = block.timestamp + 1 days;
        uint256 totalTickets = 100;
        TicketInfo memory ticketInfo = TicketInfo({ticketType: "VIP", ticketPrice: 100 ether, ticketSupply: 0});
        TicketInfo[] memory ticketInfos = new TicketInfo[](1);
        ticketInfos[0] = ticketInfo;

        vm.expectRevert("Ticket supply each type must be greater than 0");
        tikeeTron.createEvent(name, metadata, date, totalTickets, ticketInfos);
    }

    function test_createEvent_RevertIf_TotalTicketsIsZero() public {
        string memory name = "Test Event";
        string memory metadata = "This is a test event";
        uint256 date = block.timestamp + 1 days;
        uint256 totalTickets = 0;
        TicketInfo memory ticketInfo = TicketInfo({ticketType: "VIP", ticketPrice: 100 ether, ticketSupply: 100});
        TicketInfo[] memory ticketInfos = new TicketInfo[](1);
        ticketInfos[0] = ticketInfo;

        vm.expectRevert("Total tickets must be greater than 0");
        tikeeTron.createEvent(name, metadata, date, totalTickets, ticketInfos);
    }

    function test_createEvent_RevertIf_TotalTicketsIsNotEqualToSumOfTicketSupplies() public {
        string memory name = "Test Event";
        string memory metadata = "This is a test event";
        uint256 date = block.timestamp + 1 days;
        uint256 totalTickets = 100;
        TicketInfo memory ticketInfo = TicketInfo({ticketType: "VIP", ticketPrice: 100 ether, ticketSupply: 50});
        TicketInfo[] memory ticketInfos = new TicketInfo[](1);
        ticketInfos[0] = ticketInfo;

        vm.expectRevert("Total tickets must be equal to the sum of ticket supplies");
        tikeeTron.createEvent(name, metadata, date, totalTickets, ticketInfos);
    }

    function test_buyTicket() public setupEvent {
        uint256 user1StartingBalance = address(user1).balance;

        vm.prank(user1);
        tikeeTron.buyTicket{value: 50 ether}(0, "This is a test event", "VIP");
        vm.stopPrank();

        uint256 user1EndingBalance = address(user1).balance;

        assertEq(user1EndingBalance, user1StartingBalance - 50 ether);
        assertEq(tikeeTron.balanceOf(address(user1)), 1);
        assertEq(tikeeTron.tokenURI(1), "This is a test event");
        assertEq(tikeeTron.ticketSupplies(0, "VIP"), 19);
        assertEq(tikeeTron.ownerOf(1), address(user1));
        assertEq(tikeeTron.tickets(1), 0);
        assertEq(tikeeTron.ticketsSold(0), 1);
    }

    function test_buyTicket_emitsEvent() public setupEvent {
        vm.expectEmit(true, true, true, true);
        emit TikeeTron.TicketBought(1, 0, "VIP", address(user1), 50 ether);

        vm.prank(user1);
        tikeeTron.buyTicket{value: 50 ether}(0, "This is a test event", "VIP");
        vm.stopPrank();
    }

    function test_buyTicket_RefundExcessFunds() public setupEvent {
        uint256 user1StartingBalance = address(user1).balance;

        vm.prank(user1);
        tikeeTron.buyTicket{value: 100 ether}(0, "This is a test event", "VIP");
        vm.stopPrank();

        // Only 50 ether should be deducted from user1's balance
        assertEq(address(user1).balance, user1StartingBalance - 50 ether);
    }

    function test_buyTicket_transferToOrganizerAndOwner() public setupEvent {
        uint256 organizerStartingBalance = address(organizer).balance;
        uint256 ownerStartingBalance = address(owner).balance;

        vm.prank(user1);
        tikeeTron.buyTicket{value: 50 ether}(0, "This is a test event", "VIP");
        vm.stopPrank();

        uint256 organizerBalance = address(organizer).balance;
        uint256 ownerBalance = address(owner).balance;

        uint256 fee = (50 ether * FEE_PERCENTAGE) / 10000;
        assertEq(organizerBalance, organizerStartingBalance + 50 ether - fee);
        assertEq(ownerBalance, ownerStartingBalance + fee);
    }

    function test_buyTicket_RevertIf_EventHasAlreadyStarted() public setupEvent {
        vm.warp(block.timestamp + 1 days);
        vm.prank(user1);
        vm.expectRevert("Event has already started");
        tikeeTron.buyTicket{value: 50 ether}(0, "This is a test event", "VIP");
        vm.stopPrank();
    }

    function test_buyTicket_RevertIf_TicketTypeDoesNotExist() public setupEvent {
        vm.prank(user1);
        vm.expectRevert("Ticket type does not exist");
        tikeeTron.buyTicket{value: 50 ether}(0, "This is a test event", "NOT_EXIST");
        vm.stopPrank();
    }

    function test_buyTicket_RevertIf_InsufficientFunds() public setupEvent {
        vm.prank(user1);
        vm.expectRevert("Insufficient funds");
        tikeeTron.buyTicket{value: 40 ether}(0, "This is a test event", "VIP");
        vm.stopPrank();
    }

    function test_updateEvent() public setupEvent {
        vm.prank(organizer);
        tikeeTron.updateEvent(0, "Updated Event", "This is an updated event", block.timestamp + 2 days);
        vm.stopPrank();

        (string memory name, string memory metadata, address eventOrganizer, uint256 eventDate,) = tikeeTron.events(0);

        assertEq(name, "Updated Event");
        assertEq(metadata, "This is an updated event");
        assertEq(eventOrganizer, organizer);
        assertEq(eventDate, block.timestamp + 2 days);
    }

    function test_updateEvent_emitsEvent() public setupEvent {
        vm.expectEmit(true, true, true, true);
        emit TikeeTron.EventUpdated(0, "Updated Event", "This is an updated event", block.timestamp + 2 days);

        vm.prank(organizer);
        tikeeTron.updateEvent(0, "Updated Event", "This is an updated event", block.timestamp + 2 days);
        vm.stopPrank();
    }

    function test_updateEvent_RevertIf_EventHasAlreadyStarted() public setupEvent {
        vm.warp(block.timestamp + 1 days);
        vm.prank(organizer);
        vm.expectRevert("Event has already started");
        tikeeTron.updateEvent(0, "Updated Event", "This is an updated event", block.timestamp + 2 days);
        vm.stopPrank();
    }

    function test_updateEvent_RevertIf_EventDateIsInPast() public setupEvent {
        vm.prank(organizer);
        vm.expectRevert("Event date must be in the future");
        tikeeTron.updateEvent(0, "Updated Event", "This is an updated event", block.timestamp);
        vm.stopPrank();
    }

    function test_updateEvent_RevertIf_NotOrganizer() public setupEvent {
        vm.prank(user1);
        vm.expectRevert("Only the organizer can call this function");
        tikeeTron.updateEvent(0, "Updated Event", "This is an updated event", block.timestamp + 2 days);
        vm.stopPrank();
    }

    function test_updateTicketSupplies() public setupEvent {
        // Update VIP ticket supply from 20 to 10
        TicketInfo memory vipTicketInfo = TicketInfo({ticketType: "VIP", ticketPrice: 50 ether, ticketSupply: 10});
        TicketInfo memory premiumTicketInfo =
            TicketInfo({ticketType: "Premium", ticketPrice: 25 ether, ticketSupply: 30});
        TicketInfo memory regularTicketInfo =
            TicketInfo({ticketType: "Regular", ticketPrice: 10 ether, ticketSupply: 50});
        TicketInfo[] memory ticketInfos = new TicketInfo[](3);
        ticketInfos[0] = vipTicketInfo;
        ticketInfos[1] = premiumTicketInfo;
        ticketInfos[2] = regularTicketInfo;

        vm.prank(organizer);
        tikeeTron.updateTicketSupplies(0, ticketInfos, 90);
        vm.stopPrank();
    }

    function test_updateTicketSupplies_emitsEvent() public setupEvent {
        TicketInfo memory vipTicketInfo = TicketInfo({ticketType: "VIP", ticketPrice: 50 ether, ticketSupply: 10});
        TicketInfo memory premiumTicketInfo =
            TicketInfo({ticketType: "Premium", ticketPrice: 25 ether, ticketSupply: 30});
        TicketInfo memory regularTicketInfo =
            TicketInfo({ticketType: "Regular", ticketPrice: 10 ether, ticketSupply: 50});
        TicketInfo[] memory ticketInfos = new TicketInfo[](3);
        ticketInfos[0] = vipTicketInfo;
        ticketInfos[1] = premiumTicketInfo;
        ticketInfos[2] = regularTicketInfo;

        vm.prank(organizer);
        vm.expectEmit(true, true, true, true);
        emit TikeeTron.TicketSupplyUpdated(0, 90);
        tikeeTron.updateTicketSupplies(0, ticketInfos, 90);
        vm.stopPrank();
    }

    function test_updateTicketSupplies_WithZeroTicketSupply() public setupEvent {
        TicketInfo memory vipTicketInfo = TicketInfo({ticketType: "VIP", ticketPrice: 50 ether, ticketSupply: 0});
        TicketInfo memory premiumTicketInfo =
            TicketInfo({ticketType: "Premium", ticketPrice: 25 ether, ticketSupply: 30});
        TicketInfo[] memory ticketInfos = new TicketInfo[](2);
        ticketInfos[0] = vipTicketInfo;
        ticketInfos[1] = premiumTicketInfo;

        vm.prank(organizer);
        tikeeTron.updateTicketSupplies(0, ticketInfos, 30);
        vm.stopPrank();

        assertEq(tikeeTron.ticketSupplies(0, "VIP"), 0);
        assertEq(tikeeTron.ticketSupplies(0, "Premium"), 30);
    }

    function test_updateTicketSupplies_RevertIf_NotOrganizer() public setupEvent {
        TicketInfo memory vipTicketInfo = TicketInfo({ticketType: "VIP", ticketPrice: 50 ether, ticketSupply: 10});
        TicketInfo[] memory ticketInfos = new TicketInfo[](1);
        ticketInfos[0] = vipTicketInfo;

        vm.prank(user1);
        vm.expectRevert("Only the organizer can call this function");
        tikeeTron.updateTicketSupplies(0, ticketInfos, 90);
        vm.stopPrank();
    }

    function test_updateTicketSupplies_RevertIf_TotalTicketsIsNotEqualToSumOfTicketSupplies() public setupEvent {
        TicketInfo memory vipTicketInfo = TicketInfo({ticketType: "VIP", ticketPrice: 50 ether, ticketSupply: 10});
        TicketInfo[] memory ticketInfos = new TicketInfo[](1);
        ticketInfos[0] = vipTicketInfo;

        vm.prank(organizer);
        vm.expectRevert("Total tickets must be equal to the sum of ticket supplies");
        tikeeTron.updateTicketSupplies(0, ticketInfos, 90);
        vm.stopPrank();
    }

    function test_updateTicketSupplies_RevertIf_TicketInfosIsEmpty() public setupEvent {
        TicketInfo[] memory ticketInfos = new TicketInfo[](0);

        vm.prank(organizer);
        vm.expectRevert("Ticket types must be greater than 0");
        tikeeTron.updateTicketSupplies(0, ticketInfos, 90);
        vm.stopPrank();
    }

    function test_updateTicketSupplies_RevertIf_TotalTicketsIsZero() public setupEvent {
        TicketInfo[] memory ticketInfos = new TicketInfo[](1);
        ticketInfos[0] = TicketInfo({ticketType: "VIP", ticketPrice: 50 ether, ticketSupply: 0});

        vm.prank(organizer);
        vm.expectRevert("Total tickets must be greater than 0");
        tikeeTron.updateTicketSupplies(0, ticketInfos, 0);
        vm.stopPrank();
    }

    function test_updateTicketSupplies_RevertIf_EventHasAlreadyStarted() public setupEvent {
        TicketInfo memory vipTicketInfo = TicketInfo({ticketType: "VIP", ticketPrice: 50 ether, ticketSupply: 10});
        TicketInfo[] memory ticketInfos = new TicketInfo[](1);
        ticketInfos[0] = vipTicketInfo;

        vm.warp(block.timestamp + 1 days);
        vm.prank(organizer);
        vm.expectRevert("Event has already started");
        tikeeTron.updateTicketSupplies(0, ticketInfos, 10);
        vm.stopPrank();
    }

    function test_updateTicketSupplies_RevertIf_TotalTicketsCannotBeLessThanTicketsSold()
        public
        setupEvent
        buyTickets
    {
        TicketInfo memory vipTicketInfo = TicketInfo({ticketType: "VIP", ticketPrice: 50 ether, ticketSupply: 0});
        TicketInfo memory premiumTicketInfo =
            TicketInfo({ticketType: "Premium", ticketPrice: 25 ether, ticketSupply: 30});
        TicketInfo[] memory ticketInfos = new TicketInfo[](2);
        ticketInfos[0] = vipTicketInfo;
        ticketInfos[1] = premiumTicketInfo;

        vm.prank(organizer);
        vm.expectRevert("Total tickets cannot be less than tickets sold");
        tikeeTron.updateTicketSupplies(0, ticketInfos, 2);
        vm.stopPrank();
    }

    function test_getAvailableTickets() public setupEvent buyTickets {
        uint256 availableTickets = tikeeTron.getAvailableTickets(0);

        assertEq(availableTickets, 97);
    }

    function test_getAvailableTickets_WhenEventNotFound() public view {
        uint256 availableTickets = tikeeTron.getAvailableTickets(0);

        assertEq(availableTickets, 0);
    }

    function test_getAvailableTicketsByType() public setupEvent buyTickets {
        uint256 availableVipTickets = tikeeTron.getAvailableTicketsByType(0, "VIP");
        uint256 availablePremiumTickets = tikeeTron.getAvailableTicketsByType(0, "Premium");
        uint256 availableRegularTickets = tikeeTron.getAvailableTicketsByType(0, "Regular");

        assertEq(availableVipTickets, 19);
        assertEq(availablePremiumTickets, 29);
        assertEq(availableRegularTickets, 49);
    }

    function test_getAvailableTicketsByType_WhenEventNotFound() public view {
        uint256 availableTickets = tikeeTron.getAvailableTicketsByType(0, "VIP");

        assertEq(availableTickets, 0);
    }

    modifier setupEvent() {
        string memory name = "Test Event";
        string memory metadata = "This is a test event";
        uint256 date = block.timestamp + 1 days;
        uint256 totalTickets = 100;
        TicketInfo memory vipTicketInfo = TicketInfo({ticketType: "VIP", ticketPrice: 50 ether, ticketSupply: 20});
        TicketInfo memory premiumTicketInfo =
            TicketInfo({ticketType: "Premium", ticketPrice: 25 ether, ticketSupply: 30});
        TicketInfo memory regularTicketInfo =
            TicketInfo({ticketType: "Regular", ticketPrice: 10 ether, ticketSupply: 50});
        TicketInfo[] memory ticketInfos = new TicketInfo[](3);
        ticketInfos[0] = vipTicketInfo;
        ticketInfos[1] = premiumTicketInfo;
        ticketInfos[2] = regularTicketInfo;

        vm.prank(organizer);
        tikeeTron.createEvent(name, metadata, date, totalTickets, ticketInfos);
        vm.stopPrank();
        _;
    }

    modifier buyTickets() {
        vm.deal(user2, 100 ether);

        vm.startPrank(user2);
        tikeeTron.buyTicket{value: 50 ether}(0, "This is a test event", "VIP");
        tikeeTron.buyTicket{value: 30 ether}(0, "This is a test event", "Premium");
        tikeeTron.buyTicket{value: 20 ether}(0, "This is a test event", "Regular");
        vm.stopPrank();
        _;
    }
}
