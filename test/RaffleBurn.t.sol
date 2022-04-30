// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./mock/CheatCodes.sol";
import "./mock/DummyERC721.sol";
import "./mock/DummyERC20.sol";
import "../src/RaffleBurn.sol";
import "forge-std/console.sol";

contract RaffleBurnTest is CheatCodesDSTest {
    RaffleBurn rb;

    DummyERC721 nft1;
    DummyERC721 nft2;
    DummyERC721 nft3;

    DummyERC20 t1;
    DummyERC20 t2;
    DummyERC20 t3;

    uint256 constant PRICE = 100e18;
    uint96 constant MIN_TICKETS = 100;
    uint256 constant DURATION = 100;

    address a1 = 0x0000000000000000000000000000000000000001;
    address a2 = 0x0000000000000000000000000000000000000002;
    address a3 = 0x0000000000000000000000000000000000000003;
    address dead = address(0xdead);

    function setUp() public {
        nft1 = new DummyERC721();
        nft2 = new DummyERC721();
        nft3 = new DummyERC721();
        t1 = new DummyERC20();
        t2 = new DummyERC20();
        t3 = new DummyERC20();
        rb = new RaffleBurn();
        mintTokens();
    }

    function testCreateRaffle() public {
        nft1.setApprovalForAll(address(rb), true);
        uint96[] memory tokenIds = new uint96[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 2;
        uint256 raffleId = rb.createRaffle(
            address(nft1),
            tokenIds,
            address(t1),
            uint48(block.timestamp),
            uint48(block.timestamp + 100),
            100e18
        );
        assertEq(raffleId, 0);
    }

    function testBuyTickets() public {
        uint256 raffleId = createDummyRaffle();
        t1.approve(address(rb), PRICE * 100);
        rb.buyTickets(raffleId, 5);
        assertEq(t1.balanceOf(dead), PRICE * 5);
    }

    function testInitializeSeed() public {
        uint256 raffleId = createDummyRaffle();
        t1.approve(address(rb), PRICE * 100);
        rb.buyTickets(raffleId, MIN_TICKETS);
        cheats.warp(block.timestamp + DURATION + 1);
        rb.initializeSeed(raffleId);
    }

    function testFailInitializeSeed1() public {
        uint256 raffleId = createDummyRaffle();
        t1.approve(address(rb), PRICE * 100);
        rb.buyTickets(raffleId, MIN_TICKETS);
        cheats.warp(block.timestamp + DURATION);
        rb.initializeSeed(raffleId);
    }

    function testFailInitializeSeed2() public {
        uint256 raffleId = createDummyRaffle();
        t1.approve(address(rb), PRICE * 99);
        rb.buyTickets(raffleId, MIN_TICKETS);
        cheats.warp(block.timestamp + DURATION + 1);
        rb.initializeSeed(raffleId);
    }

    function testClaimPrize() public {
        uint256 raffleId = createDummyRaffle();
        t1.approve(address(rb), PRICE * 100);
        rb.buyTickets(raffleId, MIN_TICKETS);
        cheats.warp(block.timestamp + DURATION + 1);
        rb.initializeSeed(raffleId);
        uint256 prizeIndex = 0;
        uint256 ticketId = rb.getWinnerTicketId(raffleId, prizeIndex);
        address winner = rb.getWinner(raffleId, prizeIndex);
        uint256 ticketPurchaseIndex = rb.getTicketPurchaseIndex(
            raffleId,
            ticketId
        );
        rb.claimPrize(winner, raffleId, prizeIndex, ticketPurchaseIndex);
        assertEq(nft1.ownerOf(0), winner);
    }

    function createDummyRaffle() public returns (uint256 raffleId) {
        nft1.setApprovalForAll(address(rb), true);
        address[] memory poolPrizeTokens = new address[](1);
        poolPrizeTokens[0] = address(nft2);
        uint64[] memory poolPrizeTokenWeights = new uint64[](1);
        poolPrizeTokenWeights[0] = 5000;
        uint96[] memory tokenIds = new uint96[](1);
        tokenIds[0] = 0;
        raffleId = rb.createRaffle(
            address(nft1),
            tokenIds,
            address(t1),
            uint48(block.timestamp),
            uint48(block.timestamp + DURATION),
            PRICE
        );
    }

    function mintTokens() public {
        nft1.mint(address(this), 3);
        nft1.mint(a1, 3);
        nft1.mint(a2, 3);
        nft1.mint(a3, 3);
        nft2.mint(address(this), 3);
        nft2.mint(a1, 3);
        nft2.mint(a2, 3);
        nft2.mint(a3, 3);
        nft3.mint(address(this), 3);
        nft3.mint(a1, 3);
        nft3.mint(a2, 3);
        nft3.mint(a3, 3);
        t1.mint(address(this), 1000000e18);
        t1.mint(a1, 1000000e18);
        t1.mint(a2, 1000000e18);
        t1.mint(a3, 1000000e18);
        t2.mint(address(this), 1000000e18);
        t2.mint(a1, 1000000e18);
        t2.mint(a2, 1000000e18);
        t2.mint(a3, 1000000e18);
        t3.mint(address(this), 1000000e18);
        t3.mint(a1, 1000000e18);
        t3.mint(a2, 1000000e18);
        t3.mint(a3, 1000000e18);
    }
}
