// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// solhint-disable-next-line no-global-import
import "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { Options, Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";

import { GuildRegistry } from "contracts/GuildRegistry.sol";
import { SplitMain } from "contracts/fixtures/SplitMain.sol";
import { DataTypes } from "contracts/libraries/DataTypes.sol";

contract GasUsage_Fork_Test is Test {
    SplitMain private splitMain;
    GuildRegistry private registry;

    address private registryOwner;
    address[] private sortedAddresses;

    // Change this for testing
    uint256 private constant TOTAL_USERS = 167;

    function _createUser(string memory name) internal returns (address payable) {
        address payable user = payable(makeAddr(name));
        vm.deal({ account: user, newBalance: 100 ether });
        return user;
    }

    function _deployFromBytecode(bytes memory bytecode) private returns (address) {
        address addr;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            addr := create(0, add(bytecode, 32), mload(bytecode))
        }
        return addr;
    }

    function _deploy(string memory contractName, bytes memory constructorData) private returns (address) {
        bytes memory creationCode = vm.getCode(contractName);
        address deployedAddress = _deployFromBytecode(abi.encodePacked(creationCode, constructorData));
        if (deployedAddress == address(0)) {
            revert(
                string.concat(
                    "Failed to deploy contract ",
                    contractName,
                    " using constructor data '",
                    string(constructorData),
                    "'"
                )
            );
        }
        return deployedAddress;
    }

    function setUp() external {
        vm.createSelectFork(vm.rpcUrl("sepolia"), 5729305); // TODO: block No.

        registryOwner = _createUser("ProtocolGuild");

        // Deploy 0xSplit infra
        splitMain = new SplitMain();
        address[] memory accounts = new address[](2);
        accounts[0] = registryOwner;
        accounts[1] = address(this);
        uint32[] memory percentAllocations = new uint32[](2);
        percentAllocations[0] = 500_000;
        percentAllocations[1] = 500_000;
        address split = splitMain.createSplit(accounts, percentAllocations, 0, registryOwner);

        // Deploy registry
        bytes memory initParams = abi.encode(address(splitMain), split, registryOwner);

        // USING UUPS Proxy
        // // TODO: how to make it work with external libraries
        // Options memory opts;
        // opts.unsafeAllow = "external-library-linking"; // TODO: https://zpl.in/upgrades/error-006
        // // opts.unsafeSkipAllChecks = true;
        // address proxy = Upgrades.deployUUPSProxy(
        //     "NetworkRegistry.sol",
        //     abi.encodeCall(NetworkRegistry.initialize, (mainInitParams)),
        //     opts
        // );
        // console2.log("proxy", proxy);
        // registry = NetworkRegistry(proxy);

        // NOTICE: Custom Proxy deploy impl
        bytes memory initializerData = abi.encodeCall(GuildRegistry.initialize, (initParams));
        registry = new GuildRegistry();
        address impl = address(registry);
        address proxy = address(_deploy("ERC1967Proxy.sol:ERC1967Proxy.0.8.23", abi.encode(impl, initializerData)));
        registry = GuildRegistry(proxy);

        DataTypes.Member[] memory members = registry.getMembers();

        console.log("Before setup: Sepolia registry has %d members", members.length);

        vm.startPrank(registry.owner());

        // Transfer 0xSplit control
        splitMain.transferControl(split, address(registry));
        // Accept 0xSplit control
        registry.acceptSplitControl();

        address[] memory _members = new address[](TOTAL_USERS);
        uint32[] memory _activityMultipliers = new uint32[](TOTAL_USERS);
        uint32[] memory _startDates = new uint32[](TOTAL_USERS);

        for (uint256 i = 0; i < TOTAL_USERS; ) {
            _members[i] = address(uint160(0x1000 + i));
            _activityMultipliers[i] = 100;
            // force latest member to have the lowest allocation
            _startDates[i] = 1_672_531_200 + uint32(5000 * i);
            unchecked {
                ++i;
            }
        }

        registry.batchNewMembers(_members, _activityMultipliers, _startDates);

        // Verify new amount of members
        console.log("After setup: Sepolia registry has %d members", registry.totalMembers());

        // // Sort the member's addresses for testing purposes later.
        // (address[] memory addrs, , ) = registry.getMembersProperties();

        // Standard bubblesort
        // bool swapped;
        // do {
        //     swapped = false;

        //     for (uint256 i = 1; i < _members.length; ) {
        //         if (_members[i - 1] > _members[i]) {
        //             swapped = true;
        //             address temp = _members[i - 1];
        //             _members[i - 1] = _members[i];
        //             _members[i] = temp;
        //         }
        //         unchecked {
        //             ++i;
        //         }
        //     }
        // } while (swapped);

        for (uint256 i = 0; i < _members.length; ) {
            sortedAddresses.push(_members[i]);
            unchecked {
                ++i;
            }
        }

        vm.stopPrank();
    }

    modifier moveForwardTime(uint256 _seconds) {
        vm.warp(block.timestamp + _seconds);
        _;
    }

    modifier ownerContext() {
        vm.startPrank(registry.owner());
        _;
        vm.stopPrank();
    }

    // function testCalculateTotalContributions() external {
    //     uint256 totalContribution = registry.calculateTotalContributions();
    // }

    // function testUpdateSecondsActive() external {
    //     registry.updateSecondsActive();
    // }

    // function testGetMembersProperties() external {
    //     (address[] memory _members, uint32[] memory _activityMultipliers, uint32[] memory _startDates) = registry
    //         .getMembersProperties();
    // }

    // function testSetNewMember() external {
    //     vm.startPrank(registryOwner);

    //     registry.setNewMember(address(0x1337), 100, 12345678);

    //     vm.stopPrank();
    // }

    function testUpdateSecondsActive() external moveForwardTime(86_400) ownerContext {
        registry.updateSecondsActive(0);
    }

    function testUpdateAll() external moveForwardTime(86_400) ownerContext {
        registry.updateAll(0, sortedAddresses, 0);
    }
}
