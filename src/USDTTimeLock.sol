// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract USDTTimeLock {
    // 存款信息结构体
    struct DepositInfo {
        uint256 amount;
        uint256 depositTime;
        uint256 unlockTime;
        bool isDeposited;
    }

    // 全局状态变量
    IERC20 public immutable usdt;
    mapping(address => DepositInfo) public deposits;
    uint256 public constant LOCK_PERIOD = 1 days;

    // 事件
    event Deposited(address indexed user, uint256 amount, uint256 unlockTime);
    event Withdrawn(address indexed user, uint256 amount);

    // 构造函数：部署合约时初始化 USDT 地址
    constructor(address _usdtAddress) {
        usdt = IERC20(_usdtAddress);
    }

    // 存款函数
    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(!deposits[msg.sender].isDeposited, "You already have a deposit");

        uint256 currentTime = block.timestamp;
        uint256 unlockTime = currentTime + LOCK_PERIOD;

        bool success = usdt.transferFrom(msg.sender, address(this), amount);
        require(success, "Transfer failed");

        deposits[msg.sender] = DepositInfo({
            amount: amount,
            depositTime: currentTime,
            unlockTime: unlockTime,
            isDeposited: true
        });

        emit Deposited(msg.sender, amount, unlockTime);
    }

    // 取款函数
    function withdraw() external {
        DepositInfo storage userDeposit = deposits[msg.sender];

        require(userDeposit.isDeposited, "No deposit found");
        require(block.timestamp >= userDeposit.unlockTime, "Funds are still locked");

        uint256 amount = userDeposit.amount;
        delete deposits[msg.sender];

        bool success = usdt.transfer(msg.sender, amount);
        require(success, "Transfer failed");

        emit Withdrawn(msg.sender, amount);
    }

    // 查询存款信息
    function getDeposit(address user) external view returns (uint256 amount, uint256 depositTime, uint256 unlockTime, bool isDeposited) {
        DepositInfo storage userDeposit = deposits[user];
        return (
            userDeposit.amount,
            userDeposit.depositTime,
            userDeposit.unlockTime,
            userDeposit.isDeposited
        );
    }
}