// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { UD60x18 } from "@prb/math/src/UD60x18.sol";

import { DataTypes } from "../libraries/DataTypes.sol";
import {
    MemberRegistry__NotRegistered,
    SplitDistribution__AccountsOutOfOrderOrInvalid,
    SplitDistribution__EmptyDistribution,
    SplitDistribution__InactiveMember,
    SplitDistribution__MemberListSizeMismatch,
    SplitDistribution__NoActiveMembers
} from "../utils/Errors.sol";

/**
 * @title A 0xSplit allocations calculator library
 * @author DAOHaus
 * @notice A Library that calculates 0xSplit allocations using ProtocolGuild MemberRegistry
 * time-based member contributions
 * @dev The DataTypes.Members data model is used to feed member's metadata to the calculate function
 */
library PGContribCalculator {
    /// @dev used to store individual members contributions prior getting overall split percentages
    struct MemberContribution {
        /// @notice member address
        address receiverAddress;
        /// @notice member calculated contribution
        /// @dev use calculateContributionOf(member)
        uint256 calcContribution;
    }

    /// @dev constant to scale UINT values into percentages (1e6 == 100%)
    uint256 public constant PERCENTAGE_SCALE = 1e6;

    /// @dev default value used as total allocation for a split distribution.
    /// Used in 0xSplit V2
    uint256 public constant DEFAULT_TOTAL_ALLOCATION = 1e6;

    /**
     * @notice Calculate 0xSplit V1 allocations
     * @dev Verifies if the address list is sorted, has no duplicates and is valid.
     * Formula to calculate individual allocations:
     *  - (SQRT(secondsActive * activityMultiplier) * PERCENTAGE_SCALE) / totalContributions
     *  - Total allocations from all members must be equal to 0xSplit PERCENTAGE_SCALE
     * The goal of the weighting formula is to reduce the total variance range of every member weight (hence using SQRT)
     * @param _sortedList sorted list (ascending order) of members to be considered in the 0xSplit distribution
     * @return _receivers list of eligible recipients (non-zero allocation) for the next split distribution
     * @return _percentAllocations list of split allocations for each eligible recipient
     */
    function calculate(
        DataTypes.Members storage self,
        address[] memory _sortedList
    ) external view returns (address[] memory _receivers, uint32[] memory _percentAllocations) {
        uint256 activeMembers = self.totalActiveMembers;
        uint256 listSize = _sortedList.length;
        uint256 total;
        address previous;

        if (activeMembers == 0) revert SplitDistribution__NoActiveMembers();

        if (listSize != activeMembers) revert SplitDistribution__MemberListSizeMismatch();

        MemberContribution[] memory memberDistribution = new MemberContribution[](listSize);
        for (uint256 i; i < listSize; ++i) {
            address memberAddress = _sortedList[i];
            DataTypes.Member memory member = getMember(self, memberAddress);
            // check for duplicates or out-of-order addresses
            if (previous >= memberAddress) revert SplitDistribution__AccountsOutOfOrderOrInvalid(i);
            if (member.activityMultiplier == 0) revert SplitDistribution__InactiveMember(memberAddress);

            memberDistribution[i] = MemberContribution({
                // TODO: how to allow recipient to assign different addresses per network?
                receiverAddress: memberAddress,
                calcContribution: calculateContributionOf(self, member)
            });
            // get the total seconds in the last period
            // total = total + unwrap(wrap(members[memberIdx - 1].secondsActive).sqrt());
            total += memberDistribution[i].calcContribution;
            previous = memberAddress;
        }

        // define variables for split params
        _receivers = new address[](activeMembers);
        _percentAllocations = new uint32[](activeMembers);

        // define variables for second loop
        uint32 runningTotal;
        uint256 nonZeroIndex; // index counter for non zero allocations
        uint256 minAllocation = type(uint256).max;
        uint256 minAllocationIndex;
        // fill 0xSplits arrays with sorted list
        for (uint256 i; i < listSize; ++i) {
            if (memberDistribution[i].calcContribution > 0) {
                _receivers[nonZeroIndex] = memberDistribution[i].receiverAddress;
                _percentAllocations[nonZeroIndex] = uint32(
                    (memberDistribution[i].calcContribution * PERCENTAGE_SCALE) / total
                );

                runningTotal += _percentAllocations[nonZeroIndex];

                // find the recipient with lowest allocation
                if (_percentAllocations[nonZeroIndex] < minAllocation) {
                    minAllocation = _percentAllocations[nonZeroIndex];
                    minAllocationIndex = nonZeroIndex;
                }

                unchecked {
                    ++nonZeroIndex; // gas optimization: very unlikely to overflow
                }
            }
        }

        if (nonZeroIndex == 0) revert SplitDistribution__EmptyDistribution();

        // NOTICE: In case sum(percentAllocations) < PERCENTAGE_SCALE
        // the remainder will be added to the recipient with lowest allocation
        if (runningTotal != PERCENTAGE_SCALE) {
            _percentAllocations[minAllocationIndex] += uint32(PERCENTAGE_SCALE - runningTotal);
        }
    }

    /**
     * @notice Calculate 0xSplit V2 allocations
     * @dev Verifies if `_memberList` has no duplicates and is valid.
     * Formula to calculate individual allocations:
     *  - (SQRT(secondsActive * activityMultiplier) * PERCENTAGE_SCALE) / totalContributions
     *  - Total allocations from all members must be equal to 0xSplit PERCENTAGE_SCALE
     * The goal of the weighting formula is to reduce the total variance range of every member weight (hence using SQRT)
     * @param _memberList list of members to be considered in the 0xSplit distribution
     * @param _totalAllocation the total allocation of the split distribution
     * @return _recipients list of eligible recipients (non-zero allocation) for the next split distribution
     * @return _allocations list of split allocations for each eligible recipient
     */
    function calculateV2(
        DataTypes.Members storage self,
        address[] memory _memberList,
        uint256 _totalAllocation
    ) external view returns (address[] memory _recipients, uint256[] memory _allocations) {
        uint256 activeMembers = self.totalActiveMembers;
        uint256 listSize = _memberList.length;
        uint256 total;
        address previous;

        if (activeMembers == 0) revert SplitDistribution__NoActiveMembers();

        if (listSize != activeMembers) revert SplitDistribution__MemberListSizeMismatch();

        MemberContribution[] memory memberDistribution = new MemberContribution[](listSize);
        for (uint256 i; i < listSize; ++i) {
            address memberAddress = _memberList[i];
            DataTypes.Member memory member = getMember(self, memberAddress);
            // // check for duplicates or out-of-order addresses
            if (previous >= memberAddress) revert SplitDistribution__AccountsOutOfOrderOrInvalid(i);
            if (member.activityMultiplier == 0) revert SplitDistribution__InactiveMember(memberAddress);

            memberDistribution[i] = MemberContribution({
                // TODO: how to allow recipient to assign different addresses per network?
                receiverAddress: memberAddress,
                calcContribution: calculateContributionOf(self, member)
            });
            // get the total seconds in the last period
            // total = total + unwrap(wrap(members[memberIdx - 1].secondsActive).sqrt());
            total += memberDistribution[i].calcContribution;
            previous = memberAddress;
        }

        // define variables for split params
        _recipients = new address[](activeMembers);
        _allocations = new uint256[](activeMembers);

        // define variables for second loop
        uint256 runningTotal;
        uint256 nonZeroIndex; // index counter for non zero allocations
        uint256 minAllocation = type(uint256).max;
        uint256 minAllocationIndex;
        // fill 0xSplits arrays with sorted list
        for (uint256 i; i < listSize; ++i) {
            if (memberDistribution[i].calcContribution > 0) {
                _recipients[nonZeroIndex] = memberDistribution[i].receiverAddress;
                _allocations[nonZeroIndex] = (memberDistribution[i].calcContribution * _totalAllocation) / total;

                runningTotal += _allocations[nonZeroIndex];

                // find the recipient with lowest allocation
                if (_allocations[nonZeroIndex] < minAllocation) {
                    minAllocation = _allocations[nonZeroIndex];
                    minAllocationIndex = nonZeroIndex;
                }

                unchecked {
                    ++nonZeroIndex; // gas optimization: very unlikely to overflow
                }
            }
        }

        if (nonZeroIndex == 0) revert SplitDistribution__EmptyDistribution();

        // NOTICE: In case sum(percentAllocations) < _totalAllocations
        // the remainder will be added to the recipient with lowest allocation
        if (runningTotal != _totalAllocation) {
            _allocations[minAllocationIndex] += (_totalAllocation - runningTotal);
        }
    }

    /**
     * @notice Fetch a member metadata from the registry
     * @dev throw an exception if member is not in the registry
     * @param _memberAddress member address
     * @return a Member's metadata
     */
    function getMember(
        DataTypes.Members storage self,
        address _memberAddress
    ) internal view returns (DataTypes.Member memory) {
        if (self.index[_memberAddress] == 0) revert MemberRegistry__NotRegistered(_memberAddress);
        return self.db[self.index[_memberAddress] - 1];
    }

    /**
     * @notice Calculates individual contribution based on member activity
     * @dev Contribution is calculated using the following time-weighted formula
     *  - SQRT(member.secondsActive)
     * @param _member Member metadata
     * @return calculated contribution as uint256 value
     */
    function calculateContributionOf(
        DataTypes.Members storage /*self*/,
        DataTypes.Member memory _member
    ) public pure returns (uint256) {
        return UD60x18.unwrap(UD60x18.wrap(_member.secondsActive).sqrt());
    }
}
