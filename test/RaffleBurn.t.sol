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
    uint256 constant DURATION = 100;
    uint256 constant MAX_ALLOWANCE = 2**256 - 1;

    uint256 constant NFT1_MINTS = 3;
    uint256 constant NFT2_MINTS = 100;
    uint256 constant NFT3_MINTS = 0;
    uint256 constant T1_ISSUANCE = PRICE * type(uint96).max;
    uint256 constant T2_ISSUANCE = PRICE * 10;
    uint256 constant T3_ISSUANCE = 0;

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

    function testBuyTickets(uint256 allowance, uint96 ticketCount) public {
        cheats.assume(allowance >= ticketCount * PRICE);
        uint256 raffleId = createDummyRaffle(nft1, t1);
        t1.approve(address(rb), allowance);
        rb.buyTickets(raffleId, ticketCount);
        assertEq(t1.balanceOf(dead), PRICE * ticketCount);
    }

    function testCannotBuyTicketsAllowance(
        uint256 allowance,
        uint96 ticketCount
    ) public {
        cheats.assume(allowance < ticketCount * PRICE);
        uint256 raffleId = createDummyRaffle(nft1, t1);
        t1.approve(address(rb), allowance);
        cheats.expectRevert(bytes("ERC20: insufficient allowance"));
        rb.buyTickets(raffleId, ticketCount);
    }

    function testCannotBuyTicketsIssuance(uint96 ticketCount) public {
        // spend more than the issuance
        cheats.assume(T2_ISSUANCE < ticketCount * PRICE);
        uint256 raffleId = createDummyRaffle(nft1, t2);
        t2.approve(address(rb), MAX_ALLOWANCE);
        cheats.expectRevert(bytes("ERC20: transfer amount exceeds balance"));
        rb.buyTickets(raffleId, ticketCount);
    }

    function testInitializeSeed() public {
        uint256 raffleId = createDummyRaffle(nft1, t1);
        t1.approve(address(rb), MAX_ALLOWANCE);
        cheats.warp(block.timestamp + DURATION + 1);
        rb.initializeSeed(raffleId);
    }

    function testCannotInitializeSeed() public {
        uint256 raffleId = createDummyRaffle(nft1, t1);
        t1.approve(address(rb), MAX_ALLOWANCE);
        // initialize too early
        cheats.warp(block.timestamp + DURATION);
        cheats.expectRevert(bytes("Raffle has not ended"));
        rb.initializeSeed(raffleId);
    }

    function testClaimPrize() public {
        uint256 raffleId = createDummyRaffle(nft1, t1);
        t1.approve(address(rb), MAX_ALLOWANCE);
        rb.buyTickets(raffleId, 5);
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

    function createDummyRaffle(DummyERC721 prizeToken, DummyERC20 paymentToken)
        public
        returns (uint256 raffleId)
    {
        prizeToken.setApprovalForAll(address(rb), true);
        uint96[] memory tokenIds = new uint96[](1);
        tokenIds[0] = 0;
        raffleId = rb.createRaffle(
            address(prizeToken),
            tokenIds,
            address(paymentToken),
            uint48(block.timestamp),
            uint48(block.timestamp + DURATION),
            PRICE
        );
    }

    function mintTokens() public {
        nft1.mint(address(this), NFT1_MINTS);
        nft1.mint(a1, NFT1_MINTS);
        nft1.mint(a2, NFT1_MINTS);
        nft1.mint(a3, NFT1_MINTS);
        nft2.mint(address(this), NFT2_MINTS);
        nft2.mint(a1, NFT2_MINTS);
        nft2.mint(a2, NFT2_MINTS);
        nft2.mint(a3, NFT2_MINTS);
        nft3.mint(address(this), NFT3_MINTS);
        nft3.mint(a1, NFT3_MINTS);
        nft3.mint(a2, NFT3_MINTS);
        nft3.mint(a3, NFT3_MINTS);
        t1.mint(address(this), T1_ISSUANCE);
        t1.mint(a1, T1_ISSUANCE);
        t1.mint(a2, T1_ISSUANCE);
        t1.mint(a3, T1_ISSUANCE);
        t2.mint(address(this), T2_ISSUANCE);
        t2.mint(a1, T2_ISSUANCE);
        t2.mint(a2, T2_ISSUANCE);
        t2.mint(a3, T2_ISSUANCE);
        t3.mint(address(this), T3_ISSUANCE);
        t3.mint(a1, T3_ISSUANCE);
        t3.mint(a2, T3_ISSUANCE);
        t3.mint(a3, T3_ISSUANCE);
    }
}
