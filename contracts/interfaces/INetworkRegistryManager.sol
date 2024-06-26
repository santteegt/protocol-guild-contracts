// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IXReceiver } from "@connext/interfaces/core/IXReceiver.sol";

import { IMemberRegistry } from "./IMemberRegistry.sol";
import { DataTypes } from "../libraries/DataTypes.sol";

/**
 * @title A cross-chain member activity registry in sync across multiple networks
 * @author DAOHaus
 * @notice Interface to manage a cross-chain member activity registry
 * @dev Includes minimal interfaces to implement a registry to keep track of members and their
 * activity time both in the home chain as well as in any replicas living in other networks.
 * It uses Connext XApp architecture to manage registries across different networks.
 */
interface INetworkRegistryManager is IMemberRegistry, IXReceiver {
    /**
     * @notice Initializes the registry contract
     * @dev Initialization parameters are abi-encoded (i.e. through a summoner contract).
     * It should call any initializer methods from other parent contracts
     * @param _initializationParams abi-encoded parameters
     */
    function initialize(bytes memory _initializationParams) external;

    /**
     * @notice Set Connext and Updater config parameters
     * @dev Zero values in updater settings will setup the contract as a main registry
     * @param _connext Connext contract address
     * @param _updaterDomain Connext domain ID where the Updater lives
     * @param _updater Main NetworkRegistry address that will update the replica registry using the Connext bridge
     */
    function setUpdaterConfig(address _connext, uint32 _updaterDomain, address _updater) external;

    /**
     * @notice Adds a replica NetworkRegistry that should get in sync with a main registry
     * @dev Zero values on {_newRegistry} should remove/disable an existing replica
     * @param _chainId Network chainId where the replica registry lives
     * @param _newRegistry Connext domain ID and replica NetworkRegistry address
     */
    function updateNetworkRegistry(uint32 _chainId, DataTypes.Registry memory _newRegistry) external;

    /**
     * @notice Upgrade replica NetworkRegistry implementation
     * @dev Implements a UUPS proxy pattern
     * @param _chainIds a list of network chainIds where valid replicas live
     * @param _newImplementations list of new implementation addresses
     * @param _data list of calldata to be called after the each implementation is upgraded
     * @param _relayerFees a list of fees to be paid to the Connext relayer per sync message forwarded
     */
    function upgradeNetworkRegistryImplementation(
        uint32[] memory _chainIds,
        address[] memory _newImplementations,
        bytes[] memory _data,
        uint256[] memory _relayerFees
    ) external payable;

    /**
     * @notice Returns whether or not a registry has been setup as a main registry
     * @dev Verifies if updater params are set to zero
     */
    function isMainRegistry() external view returns (bool);

    /**
     * @notice Adds a new set of members to the registry and sync with replicas
     * @dev It should forward messages to stay in sync with provided replicas,
     * Must be used only if registries are in sync.
     * {msg.value} must match the total fees required to pay the Connext relayer to execute
     * forwarded messages in the destination.
     * @param _members A list of member addresses to be added to the registry
     * @param _activityMultipliers A list of activity multipliers for each new member
     * @param _startDates A list of dates when each member got active
     * @param _chainIds a list of network chainIds where valid replicas live
     * @param _relayerFees a list of fees to be paid to the Connext relayer per sync message forwarded
     */
    function syncBatchNewMembers(
        address[] memory _members,
        uint32[] memory _activityMultipliers,
        uint32[] memory _startDates,
        uint32[] calldata _chainIds,
        uint256[] calldata _relayerFees
    ) external payable;

    /**
     * @notice Updates the activity multiplier for a set of existing members and sync with replicas
     * @dev It should forward messages to stay in sync with provided replicas.
     * Must be used only if registries are in sync.
     * {msg.value} must match the total fees required to pay the Connext relayer to execute
     * forwarded messages in the destination.
     * @param _members A list of existing members
     * @param _activityMultipliers A list of new activity multipliers for each member
     * @param _chainIds a list of network chainIds where valid replicas live
     * @param _relayerFees a list of fees to be paid to the Connext relayer per sync message forwarded
     */
    function syncBatchUpdateMembersActivity(
        address[] memory _members,
        uint32[] calldata _activityMultipliers,
        uint32[] calldata _chainIds,
        uint256[] calldata _relayerFees
    ) external payable;

    /**
     * @notice Remove a set of existing members from the registry and sync with replicas
     * @dev It should forward messages to stay in sync with provided replicas.
     * Must be used only if registries are in sync.
     * {msg.value} must match the total fees required to pay the Connext relayer to execute
     * forwarded messages in the destination.
     * @param _members A list of existing members
     * @param _chainIds a list of network chainIds where valid replicas live
     * @param _relayerFees a list of fees to be paid to the Connext relayer per sync message forwarded
     */
    function syncBatchRemoveMembers(
        address[] memory _members,
        uint32[] calldata _chainIds,
        uint256[] calldata _relayerFees
    ) external payable;

    /**
     * @notice Adds and/or updates a set of members on the registry
     * @dev It should be used for syncing an already existing replica registry.
     * Make sure array parameters are of the same length
     * Activity multiplier could be set within 0-100 (%) range (i.e. 50 -> part-time 100 -> full-time)
     * but it's up to the implementer to establish the multiplier boundaries
     * @param _members A list of member addresses to be added to the registry
     * @param _activityMultipliers Activity multipliers for each new member
     * @param _startDates A list of dates when each member got active
     * @param _secondsActive A list of members reported activity in seconds
     */
    function addOrUpdateMembersBatch(
        address[] memory _members,
        uint32[] memory _activityMultipliers,
        uint32[] memory _startDates,
        uint32[] memory _secondsActive
    ) external;

    /**
     * @notice Sync the state of a set of registry members across networks.
     * Useful whether you're looking to sync a new replica from scratch or a subset of members. For example
     * this function can be used to sync member's state in batches instead of doing a full registry sync
     * which could become pretty gas intensive with a growing list of members.
     * @dev It should forward messages to stay in sync with provided replicas.
     * Be aware of the size of member list as this function can be costly or just not fit into a block gas limit
     * {msg.value} must match the total fees required to pay the Connext relayer to execute
     * forwarded messages in the destination.
     * @param _members list of member addresses you look to sync
     * @param _chainIds a list of network chainIds where valid replicas live
     * @param _relayerFees a list of fees to be paid to the Connext relayer per sync message forwarded
     */
    function syncNetworkMemberRegistry(
        address[] memory _members,
        uint32[] calldata _chainIds,
        uint256[] calldata _relayerFees
    ) external payable;

    /**
     * @notice Updates activity for each member in the registry since the last update epoch and sync with replicas
     * @dev It should forward messages to stay in sync with provided replicas.
     * {msg.value} must match the total fees required to pay the Connext relayer to execute
     * forwarded messages in the destination.
     * @param _chainIds a list of network chainIds where valid replicas live
     * @param _relayerFees a list of fees to be paid to the Connext relayer per sync message forwarded
     */
    function syncUpdateSecondsActive(uint32[] calldata _chainIds, uint256[] calldata _relayerFees) external payable;

    /**
     * @notice Updates the 0xSplit distribution on all networks based on reported member activity during the last epoch.
     * Consider calling {syncUpdateSecondsActive} prior or after applying a 0xSplit distribution update.
     * @dev It should forward messages to stay in sync with provided replicas.
     * - The registry must hold the controller role of the 0xSplit contract.
     * - Addresses in `_sorted` must be in the member registry.
     * - {msg.value} must match the total fees required to pay the Connext relayer to execute
     * forwarded messages in the destination.
     * @param _sortedList sorted list (ascending order) of members to be considered in the 0xSplit distribution
     * @param _distributionIncentive reward incentive for the address that executes the distribution (max 6.5%)
     * @param _chainIds a list of network chainIds where valid replicas live
     * @param _relayerFees a list of fees to be paid to the Connext relayer per sync message forwarded
     */
    function syncUpdateSplits(
        address[] memory _sortedList,
        uint16 _distributionIncentive,
        uint32[] calldata _chainIds,
        uint256[] calldata _relayerFees
    ) external payable;

    /**
     * @notice Executes both {updateSecondsActive} to update member's activity and {updateSplits}
     * for split distribution across all networks
     * @dev It should forward messages to stay in sync with provided replicas.
     * - The registry must hold the controller role of the 0xSplit contract.
     * - Addresses in _sortedList must be in the member registry.
     * - {msg.value} must match the total fees required to pay the Connext relayer to execute
     * forwarded messages in the destination.
     * @param _sortedList sorted list (ascending order) of members to be considered in the 0xSplit distribution
     * @param _distributionIncentive reward incentive for the address that executes the distribution (max 6.5%)
     * @param _chainIds a list of network chainIds where valid replicas live
     * @param _relayerFees a list of fees to be paid to the Connext relayer per sync message forwarded
     */
    function syncUpdateAll(
        address[] memory _sortedList,
        uint16 _distributionIncentive,
        uint32[] calldata _chainIds,
        uint256[] calldata _relayerFees
    ) external payable;

    /**
     * @notice Set Connext & Updater config settings for existing NetworkRegistry replicas via sync message
     * @dev It should forward messages to stay in sync with provided replicas.
     * - {msg.value} must match the total fees required to pay the Connext relayer to execute
     * forwarded messages in the destination.
     * @param _chainIds a list of network chainIds where valid replicas live
     * @param _connextAddrs a list Connext bridge addresses to be used on each replica
     * @param _updaterDomains a list of Connext updater domain IDs to be used on each replica
     * @param _updaterAddrs a list of updater role addresses to be used on each replica
     * @param _relayerFees a list of fees to be paid to the Connext relayer per sync message forwarded
     */
    function setNetworkUpdaterConfig(
        uint32[] memory _chainIds,
        address[] memory _connextAddrs,
        uint32[] memory _updaterDomains,
        address[] memory _updaterAddrs,
        uint256[] memory _relayerFees
    ) external payable;
}
