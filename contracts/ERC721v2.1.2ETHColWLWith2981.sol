/***
 *    ███████╗██████╗  ██████╗███████╗██████╗  ██╗    ██╗   ██╗██████╗                
 *    ██╔════╝██╔══██╗██╔════╝╚════██║╚════██╗███║    ██║   ██║╚════██╗               
 *    █████╗  ██████╔╝██║         ██╔╝ █████╔╝╚██║    ██║   ██║ █████╔╝               
 *    ██╔══╝  ██╔══██╗██║        ██╔╝ ██╔═══╝  ██║    ╚██╗ ██╔╝██╔═══╝                
 *    ███████╗██║  ██║╚██████╗   ██║  ███████╗ ██║     ╚████╔╝ ███████╗               
 *    ╚══════╝╚═╝  ╚═╝ ╚═════╝   ╚═╝  ╚══════╝ ╚═╝      ╚═══╝  ╚══════╝               
 *                                                                                    
 *     ██████╗ ██████╗ ██╗     ██╗     ███████╗ ██████╗████████╗██╗ ██████╗ ███╗   ██╗
 *    ██╔════╝██╔═══██╗██║     ██║     ██╔════╝██╔════╝╚══██╔══╝██║██╔═══██╗████╗  ██║
 *    ██║     ██║   ██║██║     ██║     █████╗  ██║        ██║   ██║██║   ██║██╔██╗ ██║
 *    ██║     ██║   ██║██║     ██║     ██╔══╝  ██║        ██║   ██║██║   ██║██║╚██╗██║
 *    ╚██████╗╚██████╔╝███████╗███████╗███████╗╚██████╗   ██║   ██║╚██████╔╝██║ ╚████║
 *     ╚═════╝ ╚═════╝ ╚══════╝╚══════╝╚══════╝ ╚═════╝   ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
 * Written by MaxFlowO2, Senior Developer and Partner of G&M² Labs
 * Follow me on https://github.com/MaxflowO2 or Twitter @MaxFlowO2
 * email: cryptobymaxflowO2@gmail.com
 *
 * Purpose: Chain ID #1-5 OpenSea compliant contracts with ERC2981 and whitelist
 * Gas Estimate as-is: 3,571,984
 *
 * Rewritten to v2.1 standards (DeveloperV2 and ReentrancyGuard)
 * Rewritten to v2.1.1 standards, removal of ERC165Storage, msg.sender => _msgSender()
 * Rewritten to v2.1.2 standards, adding _msgValue() and _txOrigin() to ContextV2 this effects
 *  ERC721.sol, ERC20.sol, Ownable.sol, Developer.sol, so all bases upgraded as of 31 Dec 2021
 */

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./token/ERC721/ERC721.sol";
import "./access/OwnableV2.sol";
import "./access/DeveloperV2.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./eip/2981/ERC2981Collection.sol";
import "./interface/IMAX721.sol";
import "./modules/Whitelist.sol";
import "./interface/IMAX721Whitelist.sol";
import "./modules/PaymentSplitter.sol";
import "./modules/BAYC.sol";
import "./modules/ContractURI.sol";

contract ERC721v2ETHCollectionWhitelist is ERC721, ERC2981Collection, BAYC, ContractURI, IMAX721, IMAX721Whitelist, ReentrancyGuard, Whitelist, PaymentSplitter, DeveloperV2, OwnableV2 {
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIdCounter;
  Counters.Counter private _teamMintCounter;
  uint256 private mintStartID;
  uint256 private mintFees;
  uint256 private mintSize;
  uint256 private teamMintSize;
  uint256 private whitelistEndNumber;
  string private base;
  bool private enableMinter;
  bool private enableWhiteList;
  bool private lockedProvenance;
  bool private lockedPayees;

  event UpdatedBaseURI(string _old, string _new);
  event UpdatedMintFees(uint256 _old, uint256 _new);
  event UpdatedMintSize(uint _old, uint _new);
  event UpdatedMintStatus(bool _old, bool _new);
  event UpdatedRoyalties(address newRoyaltyAddress, uint256 newPercentage);
  event UpdatedTeamMintSize(uint _old, uint _new);
  event UpdatedWhitelistStatus(bool _old, bool _new);
  event UpdatedPresaleEnd(uint _old, uint _new);
  event ProvenanceLocked(bool _status);
  event PayeesLocked(bool _status);

  constructor() ERC721("ERC", "721") {}

/***
 *    ███╗   ███╗██╗███╗   ██╗████████╗
 *    ████╗ ████║██║████╗  ██║╚══██╔══╝
 *    ██╔████╔██║██║██╔██╗ ██║   ██║   
 *    ██║╚██╔╝██║██║██║╚██╗██║   ██║   
 *    ██║ ╚═╝ ██║██║██║ ╚████║   ██║   
 *    ╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝   ╚═╝   
 */

  // @notice this is the mint function, mint Fees in ERC20,
  //  that locks tokens to contract, inable to withdrawl, public
  //  nonReentrant() function. More comments within code.
  // @param uint amount - number of tokens minted
  function publicMint(uint256 amount) public payable nonReentrant() {
    // @notice using Checks-Effects-Interactions
    require(lockedProvenance, "Set Providence hashes");
    require(enableMinter, "Minter not active");
    require(_msgValue() == mintFees * amount, "Wrong amount of Native Token");
    require(_tokenIdCounter.current() + amount <= mintSize, "Can not mint that many");
    if(enableWhiteList) {
      require(isWhitelist[_msgSender()], "You are not Whitelisted");
      // @notice remove from whitelist and emit (Whitelist.sol)
      _removeWhitelist(_msgSender());
      for (uint i = 0; i < amount; i++) {
        _safeMint(_msgSender(), mintID());
        _tokenIdCounter.increment();
      }
    } else {
      for (uint i = 0; i < amount; i++) {
        _safeMint(_msgSender(), mintID());
        _tokenIdCounter.increment();
      }
    }
  }

  // @notice this is the team mint function, no mint Fees in ERC20,
  //  public onlyOwner function. More comments within code
  // @param address _address - address to "airdropped" or team mint token
  function teamMint(address _address) public onlyOwner {
    require(lockedProvenance, "Set Providence hashes");
    require(teamMintSize != 0, "Team minting not enabled");
    require(_tokenIdCounter.current() < mintSize, "Can not mint that many");
    require(_teamMintCounter.current() < teamMintSize, "Can not team mint anymore");
    _safeMint(_address, mintID());
    _tokenIdCounter.increment();
    _teamMintCounter.increment();
  }

  // @notice this shifts the _tokenIdCounter to proper mint number
  // @return the tokenID number using BAYC random start point on a
  //  a fixed number of mints
  function mintID() internal view returns (uint256) {
    return (mintStartID + _tokenIdCounter.current()) % mintSize;
  }

  // Function to receive ether, msg.data must be empty
  receive() external payable {
    // From PaymentSplitter.sol
    emit PaymentReceived(_msgSender(), _msgValue());
  }

  // Function to receive ether, msg.data is not empty
  fallback() external payable {
    // From PaymentSplitter.sol
    emit PaymentReceived(_msgSender(), _msgValue());
  }

  // @notice this is a public getter for ETH blance on contract
  function getBalance() external view returns (uint) {
    return address(this).balance;
  }

/***
 *     ██████╗ ██╗    ██╗███╗   ██╗███████╗██████╗ 
 *    ██╔═══██╗██║    ██║████╗  ██║██╔════╝██╔══██╗
 *    ██║   ██║██║ █╗ ██║██╔██╗ ██║█████╗  ██████╔╝
 *    ██║   ██║██║███╗██║██║╚██╗██║██╔══╝  ██╔══██╗
 *    ╚██████╔╝╚███╔███╔╝██║ ╚████║███████╗██║  ██║
 *     ╚═════╝  ╚══╝╚══╝ ╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝
 * This section will have all the internals set to onlyOwner
 */

  // @notice this will use internal functions to set EIP 2981
  //  found in IERC2981.sol and used by ERC2981Collections.sol
  // @param address _royaltyAddress - Address for all royalties to go to
  // @param uint256 _percentage - Precentage in whole number of comission
  //  of secondary sales
  function setRoyaltyInfo(address _royaltyAddress, uint256 _percentage) public onlyOwner {
    _setRoyalties(_royaltyAddress, _percentage);
    emit UpdatedRoyalties(_royaltyAddress, _percentage);
  }

  // @notice this will set the fees required to mint using
  //  publicMint(), must enter in wei. So 1 ETH = 10**18.
  // @param uint256 _newFee - fee you set, if ETH 10**18, if
  //  an ERC20 use token's decimals in calculation
  function setMintFees(uint256 _newFee) public onlyOwner {
    uint256 oldFee = mintFees;
    mintFees = _newFee;
    emit UpdatedMintFees(oldFee, mintFees);
  }

  // @notice this will enable publicMint()
  function enableMinting() public onlyOwner {
    bool old = enableMinter;
    enableMinter = true;
    emit UpdatedMintStatus(old, enableMinter);
  }

  // @notice this will disable publicMint()
  function disableMinting() public onlyOwner {
    bool old = enableMinter;
    enableMinter = false;
    emit UpdatedMintStatus(old, enableMinter);
  }

  // @notice this will enable whitelist or "if" in publicMint()
  function enableWhitelist() public onlyOwner {
    bool old = enableWhiteList;
    enableWhiteList = true;
    emit UpdatedWhitelistStatus(old, enableWhiteList);
  }

  // @notice this will disable whitelist or "else" in publicMint()
  function disableWhitelist() public onlyOwner {
    bool old = enableWhiteList;
    enableWhiteList = false;
    emit UpdatedWhitelistStatus(old, enableWhiteList);
  }

  // @notice adding an array/list of addresses to whitelist
  //  uses internal function _addWhitelistBatch(address [] memory _addresses)
  //  of Whitelist.sol to accomplish, will revert if duplicates exist in list
  //  or array of addresses.
  // @param address [] memory _addresses - list/array of addresses
  function addWhitelistBatch(address [] memory _addresses) public onlyOwner {
    _addWhitelistBatch(_addresses);
  }

  // @notice adding one address to whitelist uses internal function
  //  _addWhitelist(address _address) of Whitelist.sol to accomplish,
  //  will revert if duplicates exists
  // @param address _address - solo address
  function addWhitelist(address _address) public onlyOwner {
    _addWhitelist(_address);
  }

  // @notice removing an array/list of addresses from whitelist
  //  uses internal function _removeWhitelistBatch(address [] memory _addresses)
  //  of Whitelist.sol to accomplish, will revert if duplicates exist in list
  //  or array of addresses.
  // @param address [] memory _addresses - list/array of addresses
  function removeWhitelistBatch(address [] memory _addresses) public onlyOwner {
    _removeWhitelistBatch(_addresses);
  }

  // @notice removing one address to whitelist uses internal function
  //  _removeWhitelist(address _address) of Whitelist.sol to accomplish,
  //  will revert if duplicates exists
  // @param address _address - solo address
  function removeWhitelist(address _address) public onlyOwner {
    _removeWhitelist(_address);
  }

/***
 *    ██████╗ ███████╗██╗   ██╗
 *    ██╔══██╗██╔════╝██║   ██║
 *    ██║  ██║█████╗  ██║   ██║
 *    ██║  ██║██╔══╝  ╚██╗ ██╔╝
 *    ██████╔╝███████╗ ╚████╔╝ 
 *    ╚═════╝ ╚══════╝  ╚═══╝  
 * This section will have all the internals set to onlyDev
 * also contains all overrides required for funtionality
 */

  // @notice will add an address to PaymentSplitter by onlyDev role
  // @param address newAddy - address to recieve payments
  // @param uint newShares - number of shares they recieve
  function addPayee(address newAddy, uint newShares) public onlyDev {
    require(!lockedPayees, "Can not set, payees locked");
    _addPayee(newAddy, newShares);
  }

  // @notice will lock payees on PaymentSplitter.sol
  function lockPayees() public onlyDev {
    require(!lockedPayees, "Can not set, payees locked");
    lockedPayees = true;
    emit PayeesLocked(lockedPayees);
  }

  // @notice will set the ContractURI for OpenSea
  // @param string memory _contractURI - IPFS URI for contract
  function setContractURI(string memory _contractURI) public onlyDev {
    _setContractURI(_contractURI);
  }

  // @notice will set "team minting" by onlyDev role
  // @param uint256 _amount - set number to mint
  function setTeamMinting(uint256 _amount) public onlyDev {
    uint256 old = teamMintSize;
    teamMintSize = _amount;
    emit UpdatedTeamMintSize(old, teamMintSize);
  }

  // @notice will set mint size by onlyDev role
  // @param uint256 _amount - set number to mint
  function setMintSize(uint256 _amount) public onlyDev {
    uint256 old = mintSize;
    mintSize = _amount;
    emit UpdatedMintSize(old, mintSize);
  }

  // @notice this will set the Provenance Hashes
  // This will also set the starting order as well!
  // Only one shot to do this, otherwise it shows as invalid
  // @param string memory _images - Provenance Hash of images in sequence
  // @param string memory _json - Provenance Hash of metadata in sequence
  function setProvenance(string memory _images, string memory _json) public onlyDev {
    require(lockedPayees, "Can not set, payees unlocked");
    require(!lockedProvenance, "Already Set!");
    // This is the initial setting
    _setProvenanceImages(_images);
    _setProvenanceJSON(_json);
    // Now to psuedo-random the starting number
    // Your API should be a random before this step!
    mintStartID = uint(keccak256(abi.encodePacked(block.timestamp, _msgSender(), _images, _json, block.difficulty))) % mintSize;
    _setStartNumber(mintStartID);
    // @notice Locks sequence
    lockedProvenance = true;
    emit ProvenanceLocked(lockedProvenance);
  }

  // @notice this will set the reveal timestamp
  // This is more for your API and not on chain...
  // @param uint256 _time - uinx time stamp for reveal (use with API's only)
  function setRevealTimestamp(uint256 _time) public onlyDev {
    _setRevealTimestamp(_time);
  }

  // @notice function useful for accidental ETH transfers to contract (to user address)
  //  wraps _user in payable to fix address -> address payable
  // @param address _user - user address to input
  // @param uint256 _amount - amount of ETH to transfer
  function sweepEthToAddress(address _user, uint256 _amount) public onlyDev {
    payable(_user).transfer(_amount);
  }

  ///
  /// Developer, these are the overrides
  ///

  // @notice solidity required override for _baseURI(), if you wish to
  //  be able to set from API -> IPFS or vice versa using setBaseURI(string)
  //  if cutting, destroy this getter, function setBaseURI(string), and 
  //  string memory private base above
  function _baseURI() internal view override returns (string memory) {
    return base;
  }

  // @notice solidity required override for supportsInterface(bytes4)
  // @param bytes4 interfaceId - bytes4 id per interface or contract
  //  calculated by ERC165 standards automatically
  function supportsInterface(bytes4 interfaceId) public view override(ERC721, IERC165) returns (bool) {
    return (
      interfaceId == type(ERC2981Collection).interfaceId  ||
      interfaceId == type(BAYC).interfaceId  ||
      interfaceId == type(ContractURI).interfaceId  ||
      interfaceId == type(IMAX721).interfaceId  ||
      interfaceId == type(IMAX721Whitelist).interfaceId ||
      interfaceId == type(ReentrancyGuard).interfaceId ||
      interfaceId == type(Whitelist).interfaceId ||
      interfaceId == type(PaymentSplitter).interfaceId ||
      interfaceId == type(DeveloperV2).interfaceId ||
      interfaceId == type(OwnableV2).interfaceId ||
      super.supportsInterface(interfaceId)
    );
  }

  // @notice will return status of Minter
  function minterStatus() external view override(IMAX721) returns (bool) {
    return enableMinter;
  }

  // @notice will return minting fees
  function minterFees() external view override(IMAX721) returns (uint256) {
    return mintFees;
  }

  // @notice will return maximum mint capacity
  function minterMaximumCapacity() external view override(IMAX721) returns (uint256) {
    return mintSize;
  }

  // @notice will return maximum "team minting" capacity
  function minterMaximumTeamMints() external view override(IMAX721) returns (uint256) {
    return teamMintSize;
  }
  // @notice will return "team mints" left
  function minterTeamMintsRemaining() external view override(IMAX721) returns (uint256) {
    return teamMintSize - _teamMintCounter.current();
  }

  // @notice will return "team mints" count
  function minterTeamMintsCount() external view override(IMAX721) returns (uint256) {
    return _teamMintCounter.current();
  }

  // @notice will return current token count
  function totalSupply() external view override(IMAX721) returns (uint256) {
    return _tokenIdCounter.current();
  }

  // @notice will return whitelist end number
  function whitelistEnd() external view override(IMAX721Whitelist) returns (uint256) {
    return whitelistEndNumber;
  }

  // @notice will return whitelist status of Minter
  function whitelistStatus() external view override(IMAX721Whitelist) returns (bool) {
    return enableWhiteList;
  }
}
