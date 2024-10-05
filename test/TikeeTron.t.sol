// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import {TikeeTron} from "../src/TikeeTron.sol";
import {TicketInfo} from "../src/types/TicketInfo.sol";
import {EventInfo} from "../src/types/EventInfo.sol";

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
        vm.deal(user2, 100 ether);
    }

    function test_createEvent() public {
        string memory name = "Test Event";
        string memory metadata = "This is a test event";
        uint256 startDate = block.timestamp + 1 days;
        uint256 endDate = block.timestamp + 3 days;
        TicketInfo memory ticketInfo = TicketInfo("VIP", 100 ether, 100, startDate, endDate);
        TicketInfo[] memory ticketInfos = new TicketInfo[](1);
        ticketInfos[0] = ticketInfo;

        vm.prank(organizer);
        tikeeTron.createEvent(name, metadata, startDate, endDate, ticketInfos);

        EventInfo memory eventInfo = tikeeTron.getEvent(0);
        assertEq(eventInfo.name, name);
        assertEq(eventInfo.metadata, metadata);
        assertEq(eventInfo.organizer, organizer);
        assertEq(eventInfo.startDate, startDate);
        assertEq(eventInfo.endDate, endDate);
        assertEq(tikeeTron.getAvailableTicketsByType(0, "VIP"), 100);
    }

    function test_createEvent_emitsEvent() public {
        string memory name = "Test Event";
        string memory metadata = "This is a test event";
        uint256 startDate = block.timestamp + 1 days;
        uint256 endDate = block.timestamp + 2 days;
        TicketInfo memory ticketInfo = TicketInfo("VIP", 100 ether, 100, startDate, endDate);
        TicketInfo[] memory ticketInfos = new TicketInfo[](1);
        ticketInfos[0] = ticketInfo;

        vm.expectEmit(true, true, true, true);
        emit TikeeTron.EventCreated(0, name, metadata, organizer, startDate, endDate);

        vm.prank(organizer);
        tikeeTron.createEvent(name, metadata, startDate, endDate, ticketInfos);
    }

    function test_createEvent_RevertIf_StartDateIsInPast() public {
        string memory name = "Test Event";
        string memory metadata = "This is a test event";
        vm.warp(block.timestamp + 1 days);
        uint256 startDate = block.timestamp - 1 days;
        uint256 endDate = block.timestamp + 1 days;
        TicketInfo memory ticketInfo = TicketInfo("VIP", 100 ether, 100, startDate, endDate);
        TicketInfo[] memory ticketInfos = new TicketInfo[](1);
        ticketInfos[0] = ticketInfo;

        vm.expectRevert("Event start date must be in the future");
        tikeeTron.createEvent(name, metadata, startDate, endDate, ticketInfos);
    }

    function test_createEvent_RevertIf_EndDateIsBeforeStartDate() public {
        string memory name = "Test Event";
        string memory metadata = "This is a test event";
        uint256 startDate = block.timestamp + 2 days;
        uint256 endDate = block.timestamp + 1 days;
        TicketInfo memory ticketInfo = TicketInfo("VIP", 100 ether, 100, startDate, endDate);
        TicketInfo[] memory ticketInfos = new TicketInfo[](1);
        ticketInfos[0] = ticketInfo;

        vm.expectRevert("Event end date must be after start date");
        tikeeTron.createEvent(name, metadata, startDate, endDate, ticketInfos);
    }

    function test_createEvent_RevertIf_TicketInfosIsEmpty() public {
        string memory name = "Test Event";
        string memory metadata = "This is a test event";
        uint256 startDate = block.timestamp + 1 days;
        uint256 endDate = block.timestamp + 2 days;
        TicketInfo[] memory ticketInfos = new TicketInfo[](0);

        vm.expectRevert("Ticket types must be greater than 0");
        tikeeTron.createEvent(name, metadata, startDate, endDate, ticketInfos);
    }

    function test_createEvent_RevertIf_TicketSupplyIsZero() public {
        string memory name = "Test Event";
        string memory metadata = "This is a test event";
        uint256 startDate = block.timestamp + 1 days;
        uint256 endDate = block.timestamp + 2 days;
        TicketInfo memory ticketInfo = TicketInfo("VIP", 100 ether, 0, startDate, endDate);
        TicketInfo[] memory ticketInfos = new TicketInfo[](1);
        ticketInfos[0] = ticketInfo;

        vm.expectRevert("Ticket supply must be greater than 0");
        tikeeTron.createEvent(name, metadata, startDate, endDate, ticketInfos);
    }

    function test_createEvent_RevertIf_TicketStartDateIsInPast() public {
        string memory name = "Test Event";
        string memory metadata = "This is a test event";
        vm.warp(block.timestamp + 1 days);
        uint256 startDate = block.timestamp + 1 days;
        uint256 endDate = block.timestamp + 2 days;
        TicketInfo memory ticketInfo = TicketInfo("VIP", 100 ether, 100, block.timestamp - 1 days, endDate);
        TicketInfo[] memory ticketInfos = new TicketInfo[](1);
        ticketInfos[0] = ticketInfo;

        vm.expectRevert("Ticket start date must be in the future");
        tikeeTron.createEvent(name, metadata, startDate, endDate, ticketInfos);
    }

    function test_createEvent_RevertIf_TicketEndDateIsBeforeStartDate() public {
        string memory name = "Test Event";
        string memory metadata = "This is a test event";
        uint256 startDate = block.timestamp + 1 days;
        uint256 endDate = block.timestamp + 3 days;
        TicketInfo memory ticketInfo = TicketInfo("VIP", 100 ether, 100, startDate, startDate - 1);
        TicketInfo[] memory ticketInfos = new TicketInfo[](1);
        ticketInfos[0] = ticketInfo;

        vm.expectRevert("Ticket end date must be after start date");
        tikeeTron.createEvent(name, metadata, startDate, endDate, ticketInfos);
    }

    function test_buyTicket() public setupEvent {
        uint256 user1StartingBalance = address(user1).balance;

        vm.warp(block.timestamp + 1 days + 1 hours); // Warp to after ticket sales start
        vm.prank(user1);
        tikeeTron.buyTicket{value: 50 ether}(0, "This is a test ticket", "VIP");

        uint256 user1EndingBalance = address(user1).balance;

        assertEq(user1EndingBalance, user1StartingBalance - 50 ether);
        assertEq(tikeeTron.balanceOf(address(user1)), 1);
        assertEq(tikeeTron.tokenURI(1), "This is a test ticket");
        assertEq(tikeeTron.getAvailableTicketsByType(0, "VIP"), 19);
        assertEq(tikeeTron.ownerOf(1), address(user1));
        assertEq(tikeeTron.getEventId(1), 0);
        assertEq(tikeeTron.ticketsSold(0), 1);
    }

    function test_buyTicket_emitsEvent() public setupEvent {
        vm.warp(block.timestamp + 1 days + 1 hours); // Warp to after ticket sales start
        vm.expectEmit(true, true, true, true);
        emit TikeeTron.TicketBought(1, 0, "VIP", address(user1), 50 ether);

        vm.prank(user1);
        tikeeTron.buyTicket{value: 50 ether}(0, "This is a test ticket", "VIP");
    }

    function test_buyTicket_transferToOrganizerAndOwner() public setupEvent {
        uint256 organizerStartingBalance = address(organizer).balance;
        uint256 ownerStartingBalance = address(owner).balance;

        vm.prank(user1);
        vm.warp(block.timestamp + 1 days + 1 hours); // Warp to after ticket sales start
        tikeeTron.buyTicket{value: 50 ether}(0, "This is a test ticket", "VIP");

        uint256 organizerBalance = address(organizer).balance;
        uint256 ownerBalance = address(owner).balance;

        uint256 fee = (50 ether * FEE_PERCENTAGE) / 10000;
        assertEq(organizerBalance, organizerStartingBalance + 50 ether - fee);
        assertEq(ownerBalance, ownerStartingBalance + fee);
    }

    function test_buyTicket_RevertIf_TicketSalesHasEnded() public setupEvent {
        vm.warp(block.timestamp + 3 days);
        vm.prank(user1);
        vm.expectRevert("Ticket sales have ended");
        tikeeTron.buyTicket{value: 50 ether}(0, "This is a test ticket", "VIP");
    }

    function test_buyTicket_RevertIf_InsufficientFunds() public setupEvent {
        vm.prank(user1);
        vm.warp(block.timestamp + 1 days + 1 hours); // Warp to after ticket sales start
        vm.expectRevert("Incorrect ticket price");
        tikeeTron.buyTicket{value: 40 ether}(0, "This is a test ticket", "VIP");
    }

    function test_buyTicket_RevertIf_TicketSalesHaveNotStarted() public setupEvent {
        vm.prank(user1);
        vm.expectRevert("Ticket sales have not started");
        tikeeTron.buyTicket{value: 50 ether}(0, "This is a test ticket", "VIP");
    }

    function test_buyTicket_RevertIf_TicketSalesHaveEnded() public setupEvent {
        vm.warp(block.timestamp + 3 days + 1 hours); // Warp to after ticket sales end
        vm.prank(user1);
        vm.expectRevert("Ticket sales have ended");
        tikeeTron.buyTicket{value: 50 ether}(0, "This is a test ticket", "VIP");
    }

    function test_buyTicket_RevertIf_TicketSuppliesAreExhausted() public setupEvent {
        vm.warp(block.timestamp + 1 days + 1 hours); // Warp to after ticket sales start
        vm.deal(user1, 1050 ether);
        for (uint256 i = 0; i < 20; i++) {
            vm.prank(user1);
            tikeeTron.buyTicket{value: 50 ether}(0, "This is a test ticket", "VIP");
        }
        vm.prank(user1);
        vm.expectRevert("Ticket supplies are exhausted");
        tikeeTron.buyTicket{value: 50 ether}(0, "This is a test ticket", "VIP");
    }

    function test_getEvent() public setupEvent {
        EventInfo memory eventInfo = tikeeTron.getEvent(0);
        assertEq(eventInfo.name, "Test Event");
        assertEq(eventInfo.metadata, "This is a test event");
        assertEq(eventInfo.organizer, organizer);
        assertEq(eventInfo.startDate, block.timestamp + 1 days);
        assertEq(eventInfo.endDate, block.timestamp + 3 days);
    }

    function test_getEventId() public setupEvent {
        vm.prank(user1);
        vm.warp(block.timestamp + 1 days + 1 hours); // Warp to after ticket sales start
        tikeeTron.buyTicket{value: 50 ether}(0, "This is a test ticket", "VIP");
        assertEq(tikeeTron.getEventId(1), 0);
    }

    function test_getAvailableTicketsByType() public setupEvent {
        assertEq(tikeeTron.getAvailableTicketsByType(0, "VIP"), 20);
        assertEq(tikeeTron.getAvailableTicketsByType(0, "Premium"), 30);
        assertEq(tikeeTron.getAvailableTicketsByType(0, "Regular"), 50);
    }

    function test_supportsInterface() public view {
        assertTrue(tikeeTron.supportsInterface(0x80ac58cd)); // ERC721
        assertTrue(tikeeTron.supportsInterface(0x5b5e139f)); // ERC721Metadata
        assertTrue(tikeeTron.supportsInterface(0x01ffc9a7)); // ERC165
    }

    function test_tokenURI() public setupEvent {
        vm.prank(user1);
        vm.warp(block.timestamp + 1 days + 1 hours); // Warp to after ticket sales start
        tikeeTron.buyTicket{value: 50 ether}(0, "This is a test ticket", "VIP");
        assertEq(tikeeTron.tokenURI(1), "This is a test ticket");
    }

    function test_buyTicket_MultipleTypes() public setupEvent {
        vm.warp(block.timestamp + 1 days + 1 hours); // Warp to after ticket sales start

        vm.startPrank(user1);
        tikeeTron.buyTicket{value: 50 ether}(0, "VIP Ticket", "VIP");
        tikeeTron.buyTicket{value: 25 ether}(0, "Premium Ticket", "Premium");
        tikeeTron.buyTicket{value: 10 ether}(0, "Regular Ticket", "Regular");
        vm.stopPrank();

        assertEq(tikeeTron.balanceOf(address(user1)), 3);
        assertEq(tikeeTron.getAvailableTicketsByType(0, "VIP"), 19);
        assertEq(tikeeTron.getAvailableTicketsByType(0, "Premium"), 29);
        assertEq(tikeeTron.getAvailableTicketsByType(0, "Regular"), 49);
        assertEq(tikeeTron.ticketsSold(0), 3);
    }

    function test_buyTicket_SameTypeManyTimes() public setupEvent {
        vm.startPrank(user1);
        vm.deal(user1, 1000 ether);
        vm.warp(block.timestamp + 1 days + 1 hours); // Warp to after ticket sales start
        for (uint256 i = 0; i < 5; i++) {
            tikeeTron.buyTicket{value: 50 ether}(0, string(abi.encodePacked("VIP Ticket ", i + 1)), "VIP");
        }
        vm.stopPrank();

        assertEq(tikeeTron.balanceOf(address(user1)), 5);
        assertEq(tikeeTron.getAvailableTicketsByType(0, "VIP"), 15);
        assertEq(tikeeTron.ticketsSold(0), 5);
    }

    function test_getAvailableTicketsByType_NonExistentEvent() public view {
        assertEq(tikeeTron.getAvailableTicketsByType(999, "VIP"), 0);
    }

    function test_getAvailableTicketsByType_NonExistentTicketType() public setupEvent {
        assertEq(tikeeTron.getAvailableTicketsByType(0, "NonExistent"), 0);
    }

    function test_buyTicket_DifferentUsers() public setupEvent {
        vm.prank(user1);
        vm.warp(block.timestamp + 1 days + 1 hours); // Warp to after ticket sales start
        tikeeTron.buyTicket{value: 50 ether}(0, "VIP Ticket User1", "VIP");

        vm.prank(user2);
        tikeeTron.buyTicket{value: 25 ether}(0, "Premium Ticket User2", "Premium");

        assertEq(tikeeTron.balanceOf(address(user1)), 1);
        assertEq(tikeeTron.balanceOf(address(user2)), 1);
        assertEq(tikeeTron.getAvailableTicketsByType(0, "VIP"), 19);
        assertEq(tikeeTron.getAvailableTicketsByType(0, "Premium"), 29);
        assertEq(tikeeTron.ticketsSold(0), 2);
    }

    modifier setupEvent() {
        string memory name = "Test Event";
        string memory metadata = "This is a test event";
        uint256 startDate = block.timestamp + 1 days;
        uint256 endDate = block.timestamp + 3 days;
        TicketInfo memory vipTicketInfo = TicketInfo("VIP", 50 ether, 20, startDate, endDate);
        TicketInfo memory premiumTicketInfo = TicketInfo("Premium", 25 ether, 30, startDate, endDate);
        TicketInfo memory regularTicketInfo = TicketInfo("Regular", 10 ether, 50, startDate, endDate);
        TicketInfo[] memory ticketInfos = new TicketInfo[](3);
        ticketInfos[0] = vipTicketInfo;
        ticketInfos[1] = premiumTicketInfo;
        ticketInfos[2] = regularTicketInfo;

        vm.prank(organizer);
        tikeeTron.createEvent(name, metadata, startDate, endDate, ticketInfos);
        _;
    }
}
