// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

//Intro
contract Paradice is ERC20, ERC20Burnable, ReentrancyGuard, Ownable, Pausable {
    uint256 public constant TOTAL_SUPPLY = 10000000000 * 10 ** 18;
    uint256 public constant REPLENISH_TIME = 20 hours; // Tokens replenish every 20 hours
    uint256 public constant MAX_TOKENS = 4; // Maximum 4 tokens
    uint256 public constant MAX_TRANSFER_AMOUNT = TOTAL_SUPPLY * 2 / 100; // Maximum transfer amount of 2% of the total supply

//Psalm 86:12

    address public feeRecipient;
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    mapping(address => uint256) private _lastCalled;
    mapping(address => uint256) private _tokens;
    mapping(address => bool) private _whitelist;

    modifier canTransfer {
        replenishTokens(msg.sender);
        require(_whitelist[msg.sender] || _tokens[msg.sender] > 0, "You can only perform this action four times per 20 hours");
        if(!_whitelist[msg.sender]) {
            _tokens[msg.sender] -= 1;
        }
        _;
    }

    constructor() ERC20("Paradice", "PARA") {
        _mint(msg.sender, TOTAL_SUPPLY);
        feeRecipient = 0x44DCF474DD6392ce7a14cF59Ce7D1de19dE8E5Ed;
        _tokens[msg.sender] = MAX_TOKENS;
        _lastCalled[msg.sender] = block.timestamp;
    }
    
    //Transaction Cooldown system
    function replenishTokens(address user) internal {
        uint256 timeSinceLast = block.timestamp - _lastCalled[user];
        uint256 periods = timeSinceLast / REPLENISH_TIME;

        if (periods > 0) {
            _tokens[user] = MAX_TOKENS; // Tokens replenish to max
            _lastCalled[user] += periods * REPLENISH_TIME;
        }
    }

    //Fee-recipient Role Transfer system
    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        require(_feeRecipient != address(0), "Fee recipient cannot be a zero address");
        feeRecipient = _feeRecipient;
    }
    
    //Whitelist function
    function addAddressToWhitelist(address _address) external onlyOwner {
        _whitelist[_address] = true;
    }

    function removeAddressFromWhitelist(address _address) external onlyOwner {
        _whitelist[_address] = false;
    }
    
    //Sliding Scale Fee Structure
    function calculateFee(uint256 _amount, address sender) public view returns (uint256) {
        if (sender == owner() || sender == feeRecipient) {
            return 0;
        }
        
        uint256 factor = 10**18;
        uint256 percentage = _amount * factor / totalSupply();
        uint256 feeRate;

        if (percentage > factor / 10) {
            feeRate = 900;  // 90%
        } else if (percentage >= factor / 100) {
            feeRate = 150;  // 15%
        } else if (percentage >= factor / 200) {
            feeRate = 100;  // 10%
        } else if (percentage >= factor / 1000) {
            feeRate = 80;  // 8%
        } else if (percentage >= factor / 2000) {
            feeRate = 50;  // 5%
        } else if (percentage >= factor / 10000) {
            feeRate = 30;  // 3%
        } else if (percentage >= factor / 20000) {
            feeRate = 15;  // 1.5%
        } else if (percentage >= factor / 100000) {
            feeRate = 8;  // 0.8%
        } else if (percentage >= factor / 200000) {
            feeRate = 4;  // 0.4%
        } else if (percentage >= factor / 1000000) {
            feeRate = 2;  // 0.2%
        } else {
            feeRate = 1;  // 0.1%
        }

        uint256 fee = _amount * feeRate / 1000;
        return fee;
    }
    
    //Transaction override system - Allowing anti-whale mechanisms to be applied to each transaction
    function transfer(address recipient, uint256 amount) public virtual override canTransfer nonReentrant whenNotPaused returns (bool) {
        require(amount <= MAX_TRANSFER_AMOUNT, "Transfer amount exceeds limit");
        require(balanceOf(msg.sender) >= amount, "Insufficient sender balance");
        uint256 fee = calculateFee(amount, msg.sender);
        uint256 transferAmount = amount - fee;
        
        require(transferAmount > 0, "Transfer amount must be greater than zero");

        if (fee > 0) {
            uint256 burnAmount = fee * 10 / 100; // Burn 10% of fee
            uint256 recipientAmount = fee * 90 / 100; // 90% of fee goes to feeRecipient

            super.transfer(BURN_ADDRESS, burnAmount);
            super.transfer(feeRecipient, recipientAmount);
        }

        super.transfer(recipient, transferAmount);

        return true;
    }

    //TransferFrom override system - Allowing anti-whale mechanisms to be applied to any third party transactions
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override canTransfer nonReentrant whenNotPaused returns (bool) {
        require(amount <= MAX_TRANSFER_AMOUNT, "Transfer amount exceeds limit");
        require(balanceOf(sender) >= amount, "Insufficient sender balance");
        uint256 fee = calculateFee(amount, sender);
        uint256 transferAmount = amount - fee;

        require(transferAmount > 0, "Transfer amount must be greater than zero");

        if (fee > 0) {
            uint256 burnAmount = fee * 10 / 100; // Burn 10% of fee
            uint256 recipientAmount = fee * 90 / 100; // 90% of fee goes to feeRecipient

            super.transferFrom(sender, BURN_ADDRESS, burnAmount);
            super.transferFrom(sender, feeRecipient, recipientAmount);
        }

        super.transferFrom(sender, recipient, transferAmount);

        return true;
    }

    //Pause function
    function pause() public virtual onlyOwner {
        _pause();
    }

    //Unpause function
    function unpause() public virtual onlyOwner {
        _unpause();
    }
}

//All to be Nice. - A2 2B 9S