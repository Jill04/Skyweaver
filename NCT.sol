// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
//import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./EternalStorageProxy.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";


interface IJungleToken{
    function mintForPublic(address to,uint mintQuantity, uint256 mintIndex) external returns(bool);
    function burn(address recipient,uint256 burnQuantity) external returns (bool);

}
contract NFTCards is Initializable,ERC721EnumerableUpgradeable{
    using SafeMath for uint256;
    using Address for address;
    using Strings for uint256;
    uint256 public startingIndexBlock;
    uint256 public  SALE_START_TIMESTAMP ;
    uint256 public  MAX_NFT_SUPPLY ;
    uint256 public  NAME_CHANGE_PRICE ;
    uint256 public NFTPrice ;
    uint256 public  REVEAL_TIMESTAMP ;
    string internal PROVENANCE ;
    uint256 public TOKENS_PER_NFT ;
    address public nctAddress;
    uint public startingIndex;

    address _admin;
    
    // Mapping from token ID to name
    mapping (uint256 => string) internal _tokenName;

    // Mapping if certain name string has already been reserved
    mapping (string => bool) internal _nameReserved;
    
    //Mapping to keep track of users that buy nft after reveal time
    mapping (uint256 => uint256)public afterReveal;
    
    //Mapping to keep track of timestamp of token
    mapping (uint256 => uint256)public tokenTimestamp;
    
    //Mapping to keep track of breeding Price
    mapping(uint256 => uint256)internal breedCount;
    
    //Mapping to keep track of breed Count
    mapping(uint256 => uint256)internal breedPrice;
    
    //Mapping to store the parents of the breeds
    mapping(uint256 => uint256[2])internal breedParents;
    
    //Mapping to specify which tokenId is bred
    mapping(uint256 => bool)internal isBred;
    using EnumerableSet for EnumerableSet.UintSet;

    


   function initialize(address admin, address _nctAddress, uint _revealTimestamp) public initializer {
        _admin = admin;
        __ERC721_init("MyCollectible", "MCO");
         nctAddress=_nctAddress;
        REVEAL_TIMESTAMP = _revealTimestamp;
         SALE_START_TIMESTAMP = 1624527897;
        MAX_NFT_SUPPLY = 10000;
        NAME_CHANGE_PRICE = 350 * (10 ** 18);
        NFTPrice = 0.08 ether;
        REVEAL_TIMESTAMP ;
        PROVENANCE = "";
        TOKENS_PER_NFT = 500 *1e18;
    }
    
    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwnerModifier() {
        address owner= _admin;
        require(tx.origin == owner, "caller is not the owner");
        _;
    }

    /*
    *Function to withdraw ether from smart contract account , callable only by owner.
    */
    // function withdraw() onlyOwnerModifier public {
    //     uint balance = address(this).balance;
    //     (msg.sender).transfer(balance);
    // }
    
    /*
    *Function mints NFT upto 20 number of NFTs.
    */
    function mintNFT(uint256 numberOfNfts) public payable {
        require(totalSupply() < MAX_NFT_SUPPLY, "Sale has already ended");
        require(numberOfNfts > 0, "numberOfNfts cannot be 0");
        require(numberOfNfts <= 20, "You may not buy more than 20 NFTs at once");
        require(totalSupply().add(numberOfNfts) <= MAX_NFT_SUPPLY, "Exceeds MAX_NFT_SUPPLY");
        require(NFTPrice.mul(numberOfNfts) == msg.value, "Ether value sent is not correct");

        for (uint i = 0; i < numberOfNfts; i++) {
            uint mintIndex = totalSupply();
            _safeMint(tx.origin, mintIndex);
             require(IJungleToken(nctAddress).mintForPublic(tx.origin,TOKENS_PER_NFT,mintIndex),"Error in transfer");
             tokenTimestamp[mintIndex] = block.timestamp;
         if(block.timestamp > REVEAL_TIMESTAMP)
            {
                afterReveal[mintIndex] = block.timestamp;
            }
        }
        
    }
    
    /**
    @dev Method for changing price, only callable by owner.
    */
    function changePrice(uint256 newPrice) public onlyOwnerModifier {
        require(newPrice> 0,"Price should be greater than zero!");
        NFTPrice=newPrice;
    }

    /**
     * @dev Reserves the name if isReserve is set to true, de-reserves if set to false
     */
    function toggleReserveName(string memory str, bool isReserve) internal {
        _nameReserved[toLower(str)] = isReserve;
    }

    /**
     * @dev Returns name of the NFT at index.
     */
    function tokenNameByIndex(uint256 index) public view returns (string memory) {
        return _tokenName[index];
    }

    /**
     * @dev Returns if the name has been reserved.
     */
    function isNameReserved(string memory nameString) public view returns (bool) {
        return _nameReserved[toLower(nameString)];
    }

    /**
    @dev Add/Set's provenance. callable only by owner.
    */
    function changeProvenace(string memory _PROVENANCE) public onlyOwnerModifier{
        PROVENANCE=_PROVENANCE;
    }
    
     /**
    @dev Add/Set's name change price. callable only by owner.
    */
    function changeNamePrice(uint256 _price) public onlyOwnerModifier{
        NAME_CHANGE_PRICE=_price;
    }

    event NameChange (uint256 indexed NFTIndex, string newName);
    /**
    @dev Change name for given "tokenId". only callable by "tokenId" owner.
    */
    function changeName(uint256 tokenId, string memory newName) public {
        address owner = ownerOf(tokenId);

        require(_msgSender() == owner, "ERC721: caller is not the owner");
        require(validateName(newName) == true, "Not a valid new name");
        require(sha256(bytes(newName)) != sha256(bytes(_tokenName[tokenId])), "New name is same as the current one");
        require(isNameReserved(newName) == false, "Name already reserved");
        
       
        // If already named, dereserve old name
        if (bytes(_tokenName[tokenId]).length > 0) {
            toggleReserveName(_tokenName[tokenId], false);
        }
        toggleReserveName(newName, true);
        _tokenName[tokenId] = newName;
        IJungleToken(nctAddress).burn(msg.sender,NAME_CHANGE_PRICE);
        
        emit NameChange(tokenId, newName);
    }
    
     function getTokenBreedPrice(uint256 _tokenId) internal  returns(uint){
        uint breedCount = getBreedCount(_tokenId);
        
        if(breedCount == 0){
           breedPrice[_tokenId] = 300 * 1e18; 
        }
        else if(breedCount == 1){
             breedPrice[_tokenId] = 600 * 1e18; 
        }
        else if(breedCount == 2){
             breedPrice[_tokenId] = 900 * 1e18; 
        }
        else if(breedCount == 3){
             breedPrice[_tokenId] = 1200 * 1e18; 
        } 
        else{
             breedPrice[_tokenId] = 1500 * 1e18; 
        }
        return breedPrice[_tokenId];
    }
    
    function getBreedCount(uint256 _tokenId)internal view returns(uint256){
        return(breedCount[_tokenId]);
    }
    
       function breed(uint256 _Parent1, uint256 _Parent2) external returns(bool){
         
        address user = msg.sender;
        uint256 mintIndex = totalSupply();
        uint256 existenceParent1 = getExistanceDaysofNFT(_Parent1);
        uint256 existenceParent2 = getExistanceDaysofNFT(_Parent2);
        require(_exists(_Parent1) && _exists(_Parent2) ,"ERR_TOKEN_DOESNOT_EXISTS");
        require(user == ownerOf(_Parent1) && user == ownerOf(_Parent2),"ERR_NOT_AUTHORIZED");
       // require(existence > 21 days,"ERR_CANNOT_BREED");
        uint256 _breedPrice1 =  getTokenBreedPrice(_Parent1);
        uint256 _breedPrice2 =  getTokenBreedPrice(_Parent2);
        _safeMint(user,mintIndex);
        breedCount[_Parent1] = breedCount[_Parent1].add(1);
         breedCount[_Parent2] = breedCount[_Parent2].add(1);
        require(IJungleToken(nctAddress).burn(msg.sender,_breedPrice1.add(_breedPrice2)),"ERR_IN_TRANSFER");
        breedParents[mintIndex] =[_Parent1,_Parent2];
        isBred[mintIndex] = true;
        return true;
    }

     function getExistanceDaysofNFT(uint _tokenId) internal view returns(uint256){
         if(!_exists(_tokenId)) return 0;
         uint256 timestamp = tokenTimestamp[_tokenId];
         uint256 Days = ((block.timestamp.sub(timestamp)));
         return Days;
     }
     
     function getBeedParents(uint256 _tokenId) external view returns(uint256[2] memory){
         require(isBred[_tokenId],"The character is not bred");
         return breedParents[_tokenId];
     }
    
    /**
    @dev Validate token name provided by caller.
    */
        function validateName(string memory str) public pure returns (bool){
        bytes memory b = bytes(str);
        if(b.length < 1) return false;
        if(b.length > 25) return false; // Cannot be longer than 25 characters
        if(b[0] == 0x20) return false; // Leading space
        if (b[b.length - 1] == 0x20) return false; // Trailing space

        bytes1 lastChar = b[0];

        for(uint i; i<b.length; i++){
            bytes1 char = b[i];

            if (char == 0x20 && lastChar == 0x20) return false; // Cannot contain continous spaces

            if(
                !(char >= 0x30 && char <= 0x39) && //9-0
                !(char >= 0x41 && char <= 0x5A) && //A-Z
                !(char >= 0x61 && char <= 0x7A) && //a-z
                !(char == 0x20) //space
            )
                return false;

            lastChar = char;
        }

        return true;
    }
    /**
    @dev Converts "str" to lowercase.
    */
    function toLower(string memory str) public pure returns (string memory){
        bytes memory bStr = bytes(str);
        bytes memory bLower = new bytes(bStr.length);
        for (uint i = 0; i < bStr.length; i++) {
            // Uppercase character
            if ((uint8(bStr[i]) >= 65) && (uint8(bStr[i]) <= 90)) {
                bLower[i] = bytes1(uint8(bStr[i]) + 32);
            } else {
                bLower[i] = bStr[i];
            }
        }
        return string(bLower);
    }
    

}
