// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract CrowdFunding is AccessControl, ReentrancyGuard, Pausable {
    struct Campaign {
        address payable owner;
        string title;
        string description;
        uint256 target;
        uint256 deadline;
        uint256 amountCollected;
        string image;
        mapping(address => uint256) donations;
    }

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    mapping(uint256 => Campaign) public campaigns;
    uint256 public numberOfCampaigns = 0;

    event CampaignCreated(uint256 campaignId, address owner);
    event DonationReceived(uint256 campaignId, address donor, uint256 amount);

     constructor(address defaultAdmin, address pauser) {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, pauser);
    }

    modifier onlyOwner(uint256 _campaignId) {
        require(msg.sender == campaigns[_campaignId].owner, "Not the campaign owner");
        _;
    }

    modifier campaignExists(uint256 _campaignId) {
        require(_campaignId < numberOfCampaigns, "Campaign does not exist");
        _;
    }

    function createCampaign(string memory _title, string memory _description, uint256 _target, uint256 _deadline, string memory _image) public whenNotPaused onlyOwner(numberOfCampaigns) {
        require(_deadline > block.timestamp, "The deadline should be a date in the future.");

        Campaign storage campaign = campaigns[numberOfCampaigns];
        campaign.owner = payable(msg.sender);
        campaign.title = _title;
        campaign.description = _description;
        campaign.target = _target;
        campaign.deadline = _deadline;
        campaign.amountCollected = 0;
        campaign.image = _image;

        emit CampaignCreated(numberOfCampaigns, msg.sender);

        numberOfCampaigns++;
    }

    function donateToCampaign(uint256 _id) public payable whenNotPaused campaignExists(_id) nonReentrant {
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp < campaign.deadline, "The campaign is over");
        require(msg.value > 0, "Donation must be greater than 0");

        campaign.donations[msg.sender] += msg.value;
        campaign.amountCollected += msg.value;

        (bool sent,) = campaign.owner.call{value: msg.value}("");
        require(sent, "Failed to send Ether");

        emit DonationReceived(_id, msg.sender, msg.value);
    }

    function getDonations(uint256 _id) view public campaignExists(_id) returns (uint256) {
        return campaigns[_id].donations[msg.sender];
    }

    function getCampaigns() public view returns (address[] memory, string[] memory, string[] memory, uint256[] memory, uint256[] memory, uint256[] memory, string[] memory) {
    address[] memory addrs = new address[](numberOfCampaigns);
    string[] memory titles = new string[](numberOfCampaigns);
    string[] memory descs = new string[](numberOfCampaigns);
    uint256[] memory targets = new uint256[](numberOfCampaigns);
    uint256[] memory deadlines = new uint256[](numberOfCampaigns);
    uint256[] memory amounts = new uint256[](numberOfCampaigns);
    string[] memory imgs = new string[](numberOfCampaigns);

    for(uint i = 0; i < numberOfCampaigns; i++) {
        Campaign storage campaign = campaigns[i];
        addrs[i] = campaign.owner;
        titles[i] = campaign.title;
        descs[i] = campaign.description;
        targets[i] = campaign.target;
        deadlines[i] = campaign.deadline;
        amounts[i] = campaign.amountCollected;
        imgs[i] = campaign.image;
    }

    return (addrs, titles, descs, targets, deadlines, amounts, imgs);
}

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function withdrawFunds(uint256 _campaignId) public onlyOwner(_campaignId) nonReentrant whenNotPaused {
        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.amountCollected > 0, "No funds to withdraw");

        uint256 amount = campaign.amountCollected;
        campaign.amountCollected = 0;

        (bool sent,) = campaign.owner.call{value: amount}("");
        require(sent, "Failed to withdraw funds");
    }
}
