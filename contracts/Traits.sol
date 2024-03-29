
pragma solidity ^0.8.0;
import "./Ownable.sol";
import "./Strings.sol";
import "./ITraits.sol";
import "./IGod.sol";

contract Traits is Ownable, ITraits {

  using Strings for uint256;

  // struct to store each trait's data for metadata and rendering
  struct Trait {
    string name;
    string png;
  }

  // mapping from trait type (index) to its name
  string[9] _traitTypes = [
    "Tone",
    "Head",
    "Clothes",
    "Eyes",
    "Nose",
    "Beard",
    "Mouth",
    "Feet",
    "Divinity"
  ];
  // storage of each traits name and base64 PNG data
  mapping(uint8 => mapping(uint8 => Trait)) public traitData;
  // mapping from divinityIndex to its score
  string[4] _divinity = [
    "8",
    "7",
    "6",
    "5"
  ];

  IGod public god;

  //constructor() {}

  /** ADMIN */

  function setGod(address _god) external onlyOwner {
    god = IGod(_god);
  }

  /**
   * administrative to upload the names and images associated with each trait
   * @param traitType the trait type to upload the traits for (see traitTypes for a mapping)
   * @param traits the names and base64 encoded PNGs for each trait
   */
  function uploadTraits(uint8 traitType, uint8[] calldata traitIds, Trait[] calldata traits) external onlyOwner {
    require(traitIds.length == traits.length, "Mismatched inputs");
    for (uint i = 0; i < traits.length; i++) {
      traitData[traitType][traitIds[i]] = Trait(
        traits[i].name,
        traits[i].png
      );
    }
  }

  /** RENDER */
  
  /**
   * generates an <image> element using base64 encoded PNGs
   * @param trait the trait storing the PNG data
   * @return the <image> element
   */
  function drawTrait(Trait memory trait) internal pure returns (string memory) {
    return string(abi.encodePacked(
      '<image x="4" y="4" width="32" height="32" image-rendering="pixelated" preserveAspectRatio="xMidYMid" xlink:href="data:image/png;base64,',
      trait.png,
      '"/>'
    ));
  }

// functions to generate random background color
  function uint2str(uint256 _i)internal pure returns (string memory _uintAsString){
      if (_i == 0) {
          return "0";
      }
    uint256 j = _i;
    uint256 len;
    while (j != 0) {
        len++;
        j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
}
   function random(string memory input) internal pure returns (uint256) {
      return uint256(keccak256(abi.encodePacked(input)));
  }
  
  function pickRandColor(uint256 tokenID)internal pure returns (string memory){
      uint256 rand = random(string(abi.encodePacked("RANDOM_BG_COLOR",Strings.toString(tokenID))));
      rand = (rand % 999999) + 100000;
      while (rand > 999999) {
            rand = (rand % 999999) + 100000;
         }
    return uint2str(rand);
    }
    
    // color palletes each index corresponds to combo
  string[] bgArr = 
  ["e0aa3e",
  "0079c0",
  "49ab81",
  "aa66cc",
  "00baba",
  "cf0000",
  "a95b0e",
  "aa552a",
  "9a9a9a",
  "faf0e6"];
  string[] radArr = 
  ["b88a44",
  "049cdb",
  "398564",
  "7744aa",
  "007c7c",
  "a00000", 
  "804a00", 
  "800000", 
  "544f4f",
  "fde8cd"];

  /**
   * generates an entire SVG by composing multiple <image> elements of PNGs
   * @param tokenId the ID of the token to generate an SVG for
   * @return a hex string to create background color
   */
  function bgColor (uint256 tokenId) internal view returns (uint256){
    uint256 index= uint256(keccak256(abi.encodePacked(bgArr[(tokenId) % 10], "RAND_COLOR",pickRandColor(tokenId))))%10;
    return index;
  }
  

  /**
   * generates an entire SVG by composing multiple <image> elements of PNGs
   * @param tokenId the ID of the token to generate an SVG for
   * @return a valid SVG of the Worshipper or God
   */
  function drawSVG(uint256 tokenId) public view returns (string memory) {
    IGod.WorshipperGod memory s = god.getTokenTraits(tokenId);
    uint8 shift = s.isWorshipper ? 0 : 9;

    string memory svgString = string(abi.encodePacked(
      drawTrait(traitData[0 + shift][s.tone]),
      s.isWorshipper ? drawTrait(traitData[1 + shift][s.head]) : drawTrait(traitData[1 + shift][s.divinityIndex]),
      s.isWorshipper ? drawTrait(traitData[2 + shift][s.clothes]) : '',
      drawTrait(traitData[3 + shift][s.eyes]),
      s.isWorshipper ? drawTrait(traitData[4 + shift][s.nose]) : '',
      s.isWorshipper ? '' : drawTrait(traitData[6 + shift][s.mouth]), //clothes need to be drawn first without mouth being drawn
      drawTrait(traitData[5 + shift][s.beard]), // beard and weapon drawn
      s.isWorshipper ? drawTrait(traitData[6 + shift][s.mouth]) : '', // mouth drawn after beard
      s.isWorshipper ? drawTrait(traitData[7 + shift][s.feet]) : ''
    ));

    uint256 womboCombo = bgColor(tokenId);

    return string(abi.encodePacked(
      '<svg id="God" width="100%" height="100%" version="1.1" viewBox="0 0 40 40" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"> <radialGradient id="radial" x1="0%" y1="0%" x2="0%" y2="100%" spreadMethod="pad"> <stop offset="60%"   stop-color="#',
      bgArr[womboCombo],
      '" stop-opacity="1"/> <stop offset="80%" stop-color="#',
      radArr[womboCombo], 
      '" stop-opacity="1"/></radialGradient> <rect x="0" y="0" width="40" height="40" style="fill:url(#radial)" />',
      svgString,
      "</svg>"
    ));
  }

  /**
   * generates an attribute for the attributes array in the ERC721 metadata standard
   * @param traitType the trait type to reference as the metadata key
   * @param value the token's trait associated with the key
   * @return a JSON dictionary for the single attribute
   */
  function attributeForTypeAndValue(string memory traitType, string memory value) internal pure returns (string memory) {
    return string(abi.encodePacked(
      '{"trait_type":"',
      traitType,
      '","value":"',
      value,
      '"}'
    ));
  }
  

  /**
   * generates an array composed of all the individual traits and values
   * @param tokenId the ID of the token to compose the metadata for
   * @return a JSON array of all of the attributes for given token ID
   */
  function compileAttributes(uint256 tokenId) public view returns (string memory) {
    IGod.WorshipperGod memory s = god.getTokenTraits(tokenId);
    string memory traits;
    if (s.isWorshipper) {
      traits = string(abi.encodePacked(
        attributeForTypeAndValue(_traitTypes[0], traitData[0][s.tone].name),',',
        attributeForTypeAndValue(_traitTypes[1], traitData[1][s.head].name),',',
        attributeForTypeAndValue(_traitTypes[2], traitData[2][s.clothes].name),',',
        attributeForTypeAndValue(_traitTypes[3], traitData[3][s.eyes].name),',',
        attributeForTypeAndValue(_traitTypes[4], traitData[4][s.nose].name),',',
        attributeForTypeAndValue(_traitTypes[5], traitData[5][s.beard].name),',',
        attributeForTypeAndValue(_traitTypes[6], traitData[6][s.mouth].name),',',
        attributeForTypeAndValue(_traitTypes[7], traitData[7][s.feet].name),','
      ));
    } else {
      traits = string(abi.encodePacked(
        attributeForTypeAndValue(_traitTypes[0], traitData[9][s.tone].name),',',
        attributeForTypeAndValue(_traitTypes[1], traitData[10][s.divinityIndex].name),',',
        attributeForTypeAndValue(_traitTypes[3], traitData[12][s.eyes].name),',',
        attributeForTypeAndValue(_traitTypes[5], traitData[14][s.beard].name),',',
        attributeForTypeAndValue(_traitTypes[6], traitData[15][s.mouth].name),',',
        attributeForTypeAndValue("Divinity Score", _divinity[s.divinityIndex]),','
      ));
    }
    return string(abi.encodePacked(
      '[',
      traits,
      '{"trait_type":"Generation","value":',
      tokenId <= god.getPaidTokens() ? '"Gen 0"' : '"Gen 1"',
      '},{"trait_type":"Type","value":',
      s.isWorshipper ? '"Worshipper"' : '"God"',
      '}]'
    ));
  }

  /**
   * generates a base64 encoded metadata response without referencing off-chain content
   * @param tokenId the ID of the token to generate the metadata for
   * @return a base64 encoded JSON dictionary of the token's metadata and SVG
   */
  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    IGod.WorshipperGod memory s = god.getTokenTraits(tokenId);

    string memory metadata = string(abi.encodePacked(
      '{"name": "',
      s.isWorshipper ? 'Worshipper #' : 'God #',
      tokenId.toString(),
      '", "description": "Go to the Temple as a Worshipper to earn $FAITH, while Gods collect 20% of the $FAITH and attempt to win the favor of the Worshippers. Immerse yourself in ancient times in pursuit of a common goal: $FAITH. All data stored on-chain on the Metis blockchain. ", "image": "data:image/svg+xml;base64,',
      base64(bytes(drawSVG(tokenId))),
      '", "attributes":',
      compileAttributes(tokenId),
      "}"
    ));

    return string(abi.encodePacked(
      "data:application/json;base64,",
      base64(bytes(metadata))
    ));
  }

  // BASE 64 - Written by Brech Devos */
  
  string internal constant TABLE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

  function base64(bytes memory data) internal pure returns (string memory) {
    if (data.length == 0) return '';
    
    // load the table into memory
    string memory table = TABLE;

    // multiply by 4/3 rounded up
    uint256 encodedLen = 4 * ((data.length + 2) / 3);

    // add some extra buffer at the end required for the writing
    string memory result = new string(encodedLen + 32);

    assembly {
      // set the actual output length
      mstore(result, encodedLen)
      
      // prepare the lookup table
      let tablePtr := add(table, 1)
      
      // input ptr
      let dataPtr := data
      let endPtr := add(dataPtr, mload(data))
      
      // result ptr, jump over length
      let resultPtr := add(result, 32)
      
      // run over the input, 3 bytes at a time
      for {} lt(dataPtr, endPtr) {}
      {
          dataPtr := add(dataPtr, 3)
          
          // read 3 bytes
          let input := mload(dataPtr)
          
          // write 4 characters
          mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr(18, input), 0x3F)))))
          resultPtr := add(resultPtr, 1)
          mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr(12, input), 0x3F)))))
          resultPtr := add(resultPtr, 1)
          mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr( 6, input), 0x3F)))))
          resultPtr := add(resultPtr, 1)
          mstore(resultPtr, shl(248, mload(add(tablePtr, and(        input,  0x3F)))))
          resultPtr := add(resultPtr, 1)
      }
      
      // padding with '='
      switch mod(mload(data), 3)
      case 1 { mstore(sub(resultPtr, 2), shl(240, 0x3d3d)) }
      case 2 { mstore(sub(resultPtr, 1), shl(248, 0x3d)) }
    }
    
    return result;
  }
}