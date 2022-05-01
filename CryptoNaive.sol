// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";



contract CryptoNaive is ERC721A, Ownable, ReentrancyGuard {

    using SafeERC20 for IERC20;
    using Strings for uint256;  

    //constants
    uint256 immutable public MAX_Totol_Supply; 
    
    


    // attributes
    address public tokenContract;
    uint256 public publicSaleStartTime;
    uint256 public Max_Per_Address; 
    uint256 public Max_Per_Tx;
    uint256 public Initial_Price;
    bytes32 public keyHash;
    uint256 public fee;
    bool    public  _isClaimActive;
    bool    public  _isDisplayPic;
    string  public  notRevealedUri;
    string  public  baseExtension = ".json";
    string  baseURI;
    mapping(address => bool)   public operator;
    mapping(uint256 => string) private _tokenURIs;

    bytes32 public saleMerkleRoot; //Whitelist vertify



    //modifiers
    modifier whenClaimActive() {
        require(_isClaimActive, "Claim is not active");
        _;
    }

    modifier whenDisplayPic() {
        require(_isDisplayPic, "Picture is not displayed");
        _;
    }

    modifier onlyOperator() {
        require(operator[msg.sender] , "Only operator can call this method");
        _;
    }

    modifier isValidMerkleProof(bytes32[] calldata merkleProof, bytes32 root) {
        require(
            MerkleProof.verify(
                merkleProof,
                root,
                keccak256(abi.encodePacked(msg.sender))
            ),
            "Address does not exist in list"
        );
        _;
    }

    //events

    constructor(
        string memory name, string memory symbol,
        address  _tokenContract,
        uint256  _MAX_Totol_Supply, uint256  _Max_Per_Address,
        uint256  _Max_Per_Tx, uint256  _Initial_Price,
        bool owner
        ) ERC721A(name, symbol) {
            tokenContract = _tokenContract;
            MAX_Totol_Supply = _MAX_Totol_Supply;
            Max_Per_Address = _Max_Per_Address;
            Max_Per_Tx = _Max_Per_Tx;
            Initial_Price = _Initial_Price;
            operator[msg.sender] = owner;
        }


    function setSaleMerkleRoot(bytes32 merkleRoot) external onlyOperator {
        saleMerkleRoot = merkleRoot;
    }
     
    function StartPublicSale() public onlyOperator {
        _isClaimActive = true;
    }

    function StoptPublicSale() public onlyOperator whenClaimActive {
       _isClaimActive = false;
    }

    function flipReveal() public onlyOperator {
        _isDisplayPic = !_isDisplayPic;
    }


    function setOperator(address _operator, bool _bool) external onlyOwner {
        operator[_operator] = _bool;
    }

    function setMaxMintPerTx(uint256 _maxMintPerTx) external onlyOperator {
        Max_Per_Tx = _maxMintPerTx;
    }

    function setMaxMintPerAddress(uint256 _maxMintPerAddress) external onlyOperator {
        Max_Per_Address = _maxMintPerAddress;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function getElapsedSaleTime() private view returns (uint256) {
        return publicSaleStartTime > 0 ? block.timestamp - publicSaleStartTime : 0;
    }

    function getMintPrice() public view whenClaimActive returns (uint256) {
        uint256 price; 
        // Linear increasing function
        price = Initial_Price + 9 * totalSupply()/MAX_Totol_Supply * Initial_Price;
        return price;
    }

    function _isWhitelist(bytes32[] calldata merkleProof) public view returns (bool) {
        return  MerkleProof.verify(merkleProof, saleMerkleRoot, keccak256(abi.encodePacked(msg.sender)));
    }

    function setNotRevealedURI(string memory _notRevealedURI) public onlyOperator {
        notRevealedUri = _notRevealedURI;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOperator {
        baseURI = _newBaseURI;
    }

    function setBaseExtension(string memory _newBaseExtension) public onlyOperator {
        baseExtension = _newBaseExtension;
    }

    function setTokenToUse(address _tokenContract) external onlyOperator {
        tokenContract = _tokenContract;
    }

    
    //mint
    function mintCryptoNaive(uint8 tokenQuantity, bytes32[] calldata merkleProof) 
        external whenClaimActive nonReentrant {
        require(msg.sender == tx.origin, "Please change the address");
        require(tokenQuantity > 0, "Must mint at least one CryproNaive");
        require(totalSupply() + tokenQuantity <= MAX_Totol_Supply, "Minting would exceed max supply");
        require(tokenQuantity + balanceOf(msg.sender) <= Max_Per_Address, "numCryNaive should not exceed MaxPerAddress");
        require(tokenQuantity <= Max_Per_Tx, "numLands should not exceed maxMintPerTx");
        //is_whitelist
        if(_isWhitelist(merkleProof)){
          _safeMint(msg.sender, tokenQuantity);
        }else{
            uint256 mintPrice = getMintPrice();
            IERC20(tokenContract).safeTransferFrom(msg.sender, address(this), mintPrice * tokenQuantity);
            _mintCryptoNaive(tokenQuantity, msg.sender);
        }
    }

    function _mintCryptoNaive(uint256 tokenQuantity, address recipient) internal {
        _safeMint(recipient, tokenQuantity);
    }

    //display
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory){
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (_isDisplayPic == false) {
            return notRevealedUri;
        }

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }
        // If there is a baseURI but no tokenURI, concatenate the tokenID to the baseURI.
        return
            string(abi.encodePacked(base, tokenId.toString(), baseExtension));
    }

    function withdraw(address to) public onlyOwner {
        uint256 balance = address(this).balance;
        if(balance > 0){
            Address.sendValue(payable(owner()), balance);
        }

        balance = IERC20(tokenContract).balanceOf(address(this));
        if(balance > 0){
            IERC20(tokenContract).safeTransfer(owner(), balance);
        }
    }

}
