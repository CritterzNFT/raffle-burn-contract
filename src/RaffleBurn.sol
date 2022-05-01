// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract RaffleBurn is VRFConsumerBaseV2 {
    struct Prize {
        address tokenAddress;
        uint96 tokenId;
        address owner;
        bool claimed;
    }

    struct Ticket {
        address owner;
        uint96 endId;
    }

    struct Raffle {
        address paymentToken;
        uint96 seed;
        uint48 startTimestamp;
        uint48 endTimestamp;
        uint256 ticketPrice;
    }

    /*
    GLOBAL STATE
    */

    VRFCoordinatorV2Interface COORDINATOR;

    uint256 public raffleCount;

    mapping(uint256 => Raffle) public raffles;
    mapping(uint256 => Prize[]) public rafflePrizes;
    mapping(uint256 => Ticket[]) public raffleTickets;
    mapping(uint256 => uint256) public requestIdToRaffleId;

    constructor(address vrfCoordinator) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
    }

    /*
    WRITE FUNCTIONS
    */

    /**
     * @notice initializes the raffle
     * @param prizeToken the address of the ERC721 token to raffle off
     * @param tokenIds the list of token ids to raffle off
     * @param paymentToken address of the ERC20 token used to buy tickets. Null address uses ETH
     * @param startTimestamp the timestamp at which the raffle starts
     * @param endTimestamp the timestamp at which the raffle ends
     * @param ticketPrice the price of each ticket
     * @return raffleId the id of the raffle
     */
    function createRaffle(
        address prizeToken,
        uint96[] calldata tokenIds,
        address paymentToken,
        uint48 startTimestamp,
        uint48 endTimestamp,
        uint256 ticketPrice
    ) external returns (uint256 raffleId) {
        require(prizeToken != address(0), "prizeToken cannot be null");
        require(paymentToken != address(0), "paymentToken cannot be null");
        require(
            endTimestamp > block.timestamp,
            "endTimestamp must be in the future"
        );
        require(ticketPrice > 0, "ticketPrice must be greater than 0");

        raffleId = raffleCount++;

        raffles[raffleId] = Raffle({
            paymentToken: paymentToken,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp,
            ticketPrice: ticketPrice,
            seed: 0
        });

        addPrizes(raffleId, prizeToken, tokenIds);
    }

    /**
     * @notice add prizes to raffle. Must have transfer approval from contract
     *  owner or token owner
     * @param raffleId the id of the raffle
     * @param prizeToken the address of the ERC721 token to raffle off
     * @param tokenIds the list of token ids to raffle off
     */
    function addPrizes(
        uint256 raffleId,
        address prizeToken,
        uint96[] calldata tokenIds
    ) public {
        require(tokenIds.length > 0, "tokenIds must be non-empty");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            IERC721(prizeToken).transferFrom(
                msg.sender,
                address(this),
                tokenIds[i]
            );
            rafflePrizes[raffleId].push(
                Prize({
                    tokenAddress: prizeToken,
                    tokenId: tokenIds[i],
                    owner: msg.sender,
                    claimed: false
                })
            );
        }
    }

    /**
     * @notice buy ticket with erc20
     * @param raffleId the id of the raffle to buy ticket for
     * @param ticketCount the number of tickets to buy
     */
    function buyTickets(uint256 raffleId, uint96 ticketCount) external {
        // transfer payment token from account
        uint256 cost = raffles[raffleId].ticketPrice * ticketCount;
        IERC20(raffles[raffleId].paymentToken).transferFrom(
            msg.sender,
            address(0xdead),
            cost
        );
        // give tickets to account
        _sendTicket(msg.sender, raffleId, ticketCount);
    }

    /**
     * @notice claim prize
     * @param to the winner address to send the prize to
     * @param prizeIndex the index of the prize to claim
     * @param ticketPurchaseIndex the index of the ticket purchase to claim prize for
     */
    function claimPrize(
        address to,
        uint256 raffleId,
        uint256 prizeIndex,
        uint256 ticketPurchaseIndex
    ) external {
        require(raffles[raffleId].seed != 0, "Winner not set");
        require(
            to == raffleTickets[raffleId][ticketPurchaseIndex].owner,
            "Not ticket owner"
        );
        uint256 ticketId = getWinnerTicketId(raffleId, prizeIndex);
        uint96 startId = ticketPurchaseIndex > 0
            ? raffleTickets[raffleId][ticketPurchaseIndex - 1].endId
            : 0;
        uint96 endId = raffleTickets[raffleId][ticketPurchaseIndex].endId;
        require(
            ticketId >= startId && ticketId < endId,
            "Ticket id out of winner range"
        );
        rafflePrizes[raffleId][prizeIndex].claimed = true;
        IERC721(rafflePrizes[raffleId][prizeIndex].tokenAddress).transferFrom(
            address(this),
            to,
            rafflePrizes[raffleId][prizeIndex].tokenId
        );
    }

    /**
     * Initialize seed for raffle
     */
    function initializeSeed(
        uint256 raffleId,
        bytes32 keyHash,
        uint64 subscriptionId
    ) external {
        require(
            raffles[raffleId].endTimestamp < block.timestamp,
            "Raffle has not ended"
        );
        require(raffles[raffleId].seed == 0, "Seed already requested");
        // Will revert if subscription is not set and funded.
        uint256 requestId = COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            3,
            300000,
            1
        );
        requestIdToRaffleId[requestId] = raffleId;
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)
        internal
        override
    {
        uint256 raffleId = requestIdToRaffleId[requestId];
        require(raffles[raffleId].seed == 0, "Seed already initialized");
        raffles[raffleId].seed = uint96(randomWords[0]);
    }

    /**
     * @dev sends ticket to account
     * @param to the account to send ticket to
     * @param raffleId the id of the raffle to send ticket for
     * @param ticketCount the number of tickets to send
     */
    function _sendTicket(
        address to,
        uint256 raffleId,
        uint96 ticketCount
    ) internal {
        uint256 purchases = raffleTickets[raffleId].length;
        uint96 ticketEndId = purchases > 0
            ? raffleTickets[raffleId][purchases - 1].endId + ticketCount
            : ticketCount;
        Ticket memory ticket = Ticket({owner: to, endId: ticketEndId});
        raffleTickets[raffleId].push(ticket);
    }

    /*
    READ FUNCTIONS
    */

    /**
     * @dev binary search for winner address
     * @param raffleId the id of the raffle to get winner for
     * @param prizeIndex the index of the prize to get winner for
     * @return winner the winner address
     */
    function getWinner(uint256 raffleId, uint256 prizeIndex)
        external
        view
        returns (address winner)
    {
        uint256 ticketId = getWinnerTicketId(raffleId, prizeIndex);
        uint256 ticketPurchaseIndex = getTicketPurchaseIndex(
            raffleId,
            ticketId
        );
        return raffleTickets[raffleId][ticketPurchaseIndex].owner;
    }

    function getTotalSales(uint256 raffleId)
        external
        view
        returns (uint256 totalSales)
    {
        return
            raffleTickets[raffleId][raffleTickets[raffleId].length - 1].endId *
            raffles[raffleId].ticketPrice;
    }

    /**
     * @dev binary search for ticket purchase index of ticketId
     * @param raffleId the id of the raffle to get winner for
     * @param ticketId the id of the ticket to get index for
     * @return ticketPurchaseIndex the purchase index of the ticket
     */
    function getTicketPurchaseIndex(uint256 raffleId, uint256 ticketId)
        public
        view
        returns (uint256 ticketPurchaseIndex)
    {
        // binary search for winner
        uint256 left = 0;
        uint256 right = raffleTickets[raffleId].length - 1;
        while (left < right) {
            uint256 mid = (left + right) / 2;
            if (raffleTickets[raffleId][mid].endId < ticketId) {
                left = mid + 1;
            } else {
                right = mid;
            }
        }
        ticketPurchaseIndex = left;
    }

    /**
     * @dev salt the seed with prize index and get the winner ticket id
     * @param raffleId the id of the raffle to get winner for
     * @param prizeIndex the index of the prize to get winner for
     * @return ticketId the id of the ticket that won
     */
    function getWinnerTicketId(uint256 raffleId, uint256 prizeIndex)
        public
        view
        returns (uint256 ticketId)
    {
        // add salt to seed
        ticketId =
            uint256(keccak256((abi.encode(raffleId, prizeIndex)))) %
            rafflePrizes[raffleId].length;
    }

    /*
    MODIFIERS
    */
}
