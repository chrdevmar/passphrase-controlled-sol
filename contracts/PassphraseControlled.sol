//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

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

    /// @notice logs when the account is provisionally unlocked
    /// @param provisionalController address of the new provisional controller
    /// @param provisionalHint the proposed new hint to apply when account goes back to being locked
    /// @param provisionalPassphraseHash the proposed new passphraseHash to apply when account goes back to being locked
    event ProvisionallyUnlocked(
        address provisionalController,
        string provisionalHint,
        bytes32 provisionalPassphraseHash
    );

    /// @notice logs when the account is unlocked
    /// @param newController address of the new controller
    /// @param newHint the new hint to apply when account goes back to being locked
    /// @param newPassphraseHash the new passphraseHash to apply when account goes back to being locked
    /// @param lockedAt the block number at which the account will go back to being locked
    event Unlocked(
        address newController,
        string newHint,
        bytes32 newPassphraseHash,
        uint256 lockedAt
    );

    /// @notice logs when the unlockPeriod is updated
    /// @param unlockPeriod the new value of unlockPeriod
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

    /// Provisionally unlock the account.
    /// @param _provisionalHint the new hint to apply after account is unlocked
    /// @param _provisionalPassphraseHash the new passphrase hash output to apply after account is unlocked
    /// @dev sets the caller as the provisional controller
    /// @dev provisionalHint and provisionalPassphraseHash only come into effect if the account is unlocked while these
    ///      are the provisional hint and passphrase hash
    /// @dev emits ProvisionallyUnlocked event
    /// @dev emits ProvisionallyUnlocked event
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

    /// Unlock the account
    /// This can only be called by the provisional controller
    /// @param _passphrase the input which when hashed will match the current passphraseHash
    /// @dev sets the provisionalController as the controller
    /// @dev unlocks the account for <unlockPeriod> blocks
    /// @dev emits Unlocked event
    function unlock(
        string memory _passphrase
    ) public onlyLocked {
        require(keccak256(abi.encodePacked(_passphrase)) == passphraseHash, "Incorrect passphrase");
        require(provisionalController == msg.sender, "Not provisional controller");
        uint256 _lockedAt = block.number + unlockPeriod;

        lockedAt = _lockedAt;
        controller = provisionalController;
        hint = provisionalHint;
        passphraseHash = provisionalPassphraseHash;

        emit Unlocked(msg.sender, provisionalHint, provisionalPassphraseHash, _lockedAt);
    }

    /// Execute arbitrary calls with arbitrary value from this contract address
    /// @param _targets array of target addresses to call
    /// @param _calldata array of encoded calldata to use
    /// @param _values array of values to use in calls
    /// @dev this can only be called by the controller while the account is unlocked
    /// @dev this performs all calls atomically, if one fails the whole transaction will revert
    /// @dev all input arrays must have matching lengths
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

    /// Set a new unlockPeriod
    /// @param _unlockPeriod new unlockPeriod value
    /// @dev this can only be called by the controller while the account is unlocked
    /// @dev emits UnlockPeriodUpdated event
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
