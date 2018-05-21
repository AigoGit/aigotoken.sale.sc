pragma solidity ^0.4.21;

contract MultiOwnable {
    address[] public owners;

    function ownersCount() public view returns(uint256) {
        return owners.length;
    }

    event OwnerAdded(address indexed owner);
    event OwnerRemoved(address indexed owner);

    constructor() public {
        owners.push(msg.sender);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(msg.sender));
        _;
    }

    function isOwner(address addr) public view returns (bool) {
        bool _isOwner = false;
        for (uint i=0; i<owners.length; i++) {
            if (addr == owners[i]) {
                _isOwner = true;
                break;
            }
        }
        return _isOwner;
    }

    function addOwner(address owner) public onlyOwner {
        require(owner != address(0));
        require(!isOwner(owner));
        owners.push(owner);
        emit OwnerAdded(owner);
    }
    function removeOwner(address owner) public onlyOwner {
        require(owner != address(0));
        require(owner != msg.sender);
        bool wasDeleted = false;
        for (uint i=0; i<owners.length; i++) {
            if (owners[i] == owner) {
                if (i < owners.length-1) {
                    owners[i] = owners[owners.length-1];
                }
                owners.length--;
                wasDeleted = true;
            }
        }
        require(wasDeleted);
        emit OwnerRemoved(owner);
    }

}
