// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/USDTTimeLock.sol";
import "../src/MockUSDT.sol";

contract USDTTimeLockTest is Test {
    // 合约实例
    MockUSDT public mockUSDT;
    USDTTimeLock public timeLock;

    // 测试用户
    address public user1 = address(0x123);
    address public user2 = address(0x456);

    // 存款金额：100 USDT，注意乘以 10^6
    uint256 public constant DEPOSIT_AMOUNT = 100 * 10**6;

    // 部署合约、准备测试环境
    function setUp() public {
        // 部署 MockUSDT 和 USDTTimeLock
        mockUSDT = new MockUSDT();
        timeLock = new USDTTimeLock(address(mockUSDT));

        // 给两个用户铸造足够的 USDT
        mockUSDT.mint(user1, DEPOSIT_AMOUNT * 2);
        mockUSDT.mint(user2, DEPOSIT_AMOUNT * 2);

        // 用户提前给时间锁合约授权
        vm.prank(user1);
        mockUSDT.approve(address(timeLock), DEPOSIT_AMOUNT);

        vm.prank(user2);
        mockUSDT.approve(address(timeLock), DEPOSIT_AMOUNT);
    }

    // 1. 用户成功存入 USDT
    // 2. 存入后，合约中的 USDT 余额增加
    function testDepositUSDT() public {
        uint256 initialContractBalance = mockUSDT.balanceOf(address(timeLock));
        uint256 initialUserBalance = mockUSDT.balanceOf(user1);

        // user1 调用 deposit
        vm.prank(user1);
        timeLock.deposit(DEPOSIT_AMOUNT);

        // 验证合约余额增加
        assertEq(
            mockUSDT.balanceOf(address(timeLock)),
            initialContractBalance + DEPOSIT_AMOUNT
        );

        // 验证用户余额减少
        assertEq(
            mockUSDT.balanceOf(user1),
            initialUserBalance - DEPOSIT_AMOUNT
        );

        // 验证存款记录
        (uint256 amount, uint256 depositTime, uint256 unlockTime, bool isDeposited) =
            timeLock.getDeposit(user1);

        assertEq(amount, DEPOSIT_AMOUNT);
        assertEq(isDeposited, true);
        assertEq(unlockTime, depositTime + 1 days);
    }

    // 3. 未满 1 天时，用户取款失败
    function testCannotWithdrawBeforeOneDay() public {
        // 先存款
        vm.prank(user1);
        timeLock.deposit(DEPOSIT_AMOUNT);

        // 尝试立即取款，预期 revert
        vm.prank(user1);
        vm.expectRevert("Funds are still locked");
        timeLock.withdraw();
    }

    // 4. 使用 vm.warp 模拟时间经过 1 天
    // 5. 满 1 天后，用户可以成功取回 USDT
    // 6. 取回后，用户的存款记录被清除
    function testWithdrawAfterOneDay() public {
        // 先存款
        vm.prank(user1);
        timeLock.deposit(DEPOSIT_AMOUNT);

        // 模拟时间前进 1 天
        vm.warp(block.timestamp + 1 days);

        uint256 initialContractBalance = mockUSDT.balanceOf(address(timeLock));
        uint256 initialUserBalance = mockUSDT.balanceOf(user1);

        // 用户取款
        vm.prank(user1);
        timeLock.withdraw();

        // 验证合约余额减少
        assertEq(
            mockUSDT.balanceOf(address(timeLock)),
            initialContractBalance - DEPOSIT_AMOUNT
        );

        // 验证用户余额恢复
        assertEq(
            mockUSDT.balanceOf(user1),
            initialUserBalance + DEPOSIT_AMOUNT
        );

        // 验证存款记录已清除
        (, , , bool isDeposited) = timeLock.getDeposit(user1);
        assertEq(isDeposited, false);
    }

    // 7. 非本人不能取走其他用户的 USDT
    function testOtherUserCannotWithdraw() public {
        // user1 存款
        vm.prank(user1);
        timeLock.deposit(DEPOSIT_AMOUNT);

        // 时间前进 1 天
        vm.warp(block.timestamp + 1 days);

        // user2 尝试取 user1 的钱，预期 revert
        vm.prank(user2);
        vm.expectRevert("No deposit found");
        timeLock.withdraw();
    }
}