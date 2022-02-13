//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract PassphraseControlled {
    string public name;
    uint256 public lockedAt;
    uint256 public unlockPeriod;

    string public hint;
    bytes32 public passphraseHash;
    address public controller;

    string public provisionalHint;
    bytes32 public provisionalPassphraseHash;
    address public provisionalController;

    event ProvisionallyUnlocked(
        address provisionalController,
        string provisionalHint,
        bytes32 provisionalPassphraseHash
    );

    event Unlocked(
        address newController,
        string newHint,
        bytes32 newPassphraseHash
    );

    event UnlockPeriodUpdated(
        uint256 unlockPeriod
    );

    constructor(
        string memory _name,
        string memory _hint,
        bytes32 _passphraseHash,
        uint256 _unlockPeriod
    ) {
        require(_unlockPeriod > 0, "Unlock period must be > 0");
        name = _name;
        hint = _hint;
        passphraseHash = _passphraseHash;
        lockedAt = block.number;
        controller = address(0x0000000000000000000000000000000000000000);
        provisionalController = address(0x0000000000000000000000000000000000000000);
        unlockPeriod = _unlockPeriod;
    }

    receive() external payable {}

    function provisionalUnlock(
        string memory _provisionalHint,
        bytes32 _provisionalPassphraseHash
    ) public onlyLocked {
        require(passphraseHash != _provisionalPassphraseHash, "Provisional passphrase same as current passphrase");

        provisionalController = msg.sender;
        provisionalHint = _provisionalHint;
        provisionalPassphraseHash = _provisionalPassphraseHash;
        emit ProvisionallyUnlocked(msg.sender, _provisionalHint, _provisionalPassphraseHash);
    }

    function unlock(
        string memory _passphrase
    ) public onlyLocked {
        require(keccak256(abi.encodePacked(_passphrase)) == passphraseHash, "Incorrect passphrase");
        require(provisionalController == msg.sender, "Not provisional controller");
        lockedAt = block.number + unlockPeriod;
        controller = provisionalController;
        hint = provisionalHint;
        passphraseHash = provisionalPassphraseHash;

        emit Unlocked(msg.sender, provisionalHint, provisionalPassphraseHash);
    }

    function execute(
        address[] memory _targets,
        bytes[] memory _calldata,
        uint256[] memory _values
    ) public onlyControllerUnlocked {
        require(_targets.length > 0, "No targets provided");
        require(_targets.length == _calldata.length, "Argument length mismatch");
        require(_targets.length == _values.length, "Argument length mismatch");

        for (uint256 i = 0; i < _targets.length; i++) {
            (bool success,) =_targets[i].call{ value: _values[i] }(_calldata[i]);
            require(success, "One or more calls failed");
        }
    }

    function setUnlockPeriod(
        uint256 _unlockPeriod
    ) public onlyControllerUnlocked {
        require(_unlockPeriod > 0, "Unlock period must be > 0");

        unlockPeriod = _unlockPeriod;

        emit UnlockPeriodUpdated(_unlockPeriod);
    }

    modifier onlyControllerUnlocked() {
        require(lockedAt > block.number, "Account is locked");
        require(controller == msg.sender, "Not controller");
        _;
    }

    modifier onlyLocked() {
        require(lockedAt <= block.number, "Account is unlocked");
        _;
    }
}
