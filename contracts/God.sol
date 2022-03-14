

pragma solidity ^0.8.0;
import "./Ownable.sol";
import "./Pausable.sol";
import "./ERC721Enumerable.sol";
import "./IGod.sol";
import "./ITemple.sol";
import "./ITraits.sol";
import "./FAITH.sol";

contract God is IGod, ERC721Enumerable, Ownable, Pausable {
    // mint price
    uint256 public constant MINT_PRICE = .00001 ether;
    // max number of tokens that can be minted - 50000 in production
    uint256 public immutable MAX_TOKENS;
    // number of tokens that can be claimed for free - 20% of MAX_TOKENS
    uint256 public PAID_TOKENS;
    // number of tokens have been minted so far
    uint16 public minted;

    // mapping from tokenId to a struct containing the token's traits
    mapping(uint256 => WorshipperGod) public tokenTraits;
    // mapping from hashed(tokenTrait) to the tokenId it's associated with
    // used to ensure there are no duplicates
    mapping(uint256 => uint256) public existingCombinations;

    // list of probabilities for each trait type
    // 0 - 9 are associated with Worshipper, 10 - 18 are associated with God
    uint8[][18] public rarities;
    // list of aliases for Walker's Alias algorithm
    // 0 - 9 are associated with Worshipper, 10 - 18 are associated with God
    uint8[][18] public aliases;
    //bool to enable or disable god stealing mechanic
    bool public setSteal;

    // reference to the Temple for choosing random God steals favor
    ITemple public temple;
    // reference to $FAITH for burning on mint
    FAITH public faith;
    // reference to Traits
    ITraits public traits;

    /**
     * instantiates contract and rarity tables
     */
    constructor(
        address _faith,
        address _traits,
        uint256 _maxTokens
    ) ERC721("God Game", "GGAME") {
        faith = FAITH(_faith);
        traits = ITraits(_traits);
        MAX_TOKENS = _maxTokens;
        PAID_TOKENS = _maxTokens / 5;

        // A.J. Walker's Alias Algorithm
        // human
        // tone
        //4
        rarities[0] = [130, 130, 130, 130, 80, 80, 80, 80];
        aliases[0] = [2, 1, 3, 1, 6, 2, 3, 4];
        // head
        //18
        rarities[1] = [
            190,
            215,
            200,
            110,
            130,
            135,
            160,
            185,
            200,
            200,
            210,
            200,
            200,
            200,
            100,
            100,
            180,
            180,
            200,
            180,
            100,
            100,
            120,
            120,
            100,
            200,
            180,
            200,
            190,
            100
        ];
        aliases[1] = [
            1,
            12,
            4,
            0,
            3,
            6,
            7,
            9,
            0,
            10,
            11,
            15,
            2,
            0,
            12,
            14,
            9,
            8,
            6,
            14,
            24,
            23,
            13,
            18,
            27,
            11,
            19,
            28,
            5,
            1

        ];
        // clothes
        //8
        rarities[2] = [100, 100, 120, 90, 180, 140, 90, 150, 150, 120, 100, 120, 90, 100, 100, 90];
        aliases[2] = [12, 6, 2, 0, 1, 3, 2, 5, 8, 4, 10, 9, 7, 11, 13, 14];
        // eyes
        //17
        rarities[3] = [
            220,
            221,
            100,
            181,
            140,
            224,
            147,
            90,
            228,
            140,
            224,
            200,
            130,
            180,
            207,
            173,
            84,
            80,
            90,
            100 
        ];
        aliases[3] = [
            1,
            2,
            5,
            0,
            3,
            7,
            1,
            10,
            5,
            10,
            4,
            12,
            11,
            9,
            16,
            11,
            6,
            8,
            17,
            14
        ];
        // nose
        rarities[4] = [75, 100, 40];
        aliases[4] = [2, 0, 1];
        // facial hair
        //5
        rarities[5] = [80, 225, 227, 228, 112, 220, 140];
        aliases[5] = [6, 1, 2, 3, 4, 0, 5];
        // Mouth
        rarities[6] = [190, 227, 112, 200, 180];
        aliases[6] = [0, 2, 4, 1, 3];
        // Feet
        rarities[7] = [220, 190, 190, 60, 50, 60, 60, 50];
        aliases[7] = [2, 1, 2, 0, 1, 5, 3, 7];
        // divinityIndex
        rarities[8] = [255];
        aliases[8] = [0];

        // GODS
        // tone
        rarities[9] = [120, 120, 120, 120, 80, 80, 50];
        aliases[9] = [2, 3, 2, 0, 1, 5, 3];
        // halo
        rarities[10] = [10, 100, 180, 250];
        aliases[10] = [0, 1, 2, 3];
        // 
        rarities[11] = [255];
        aliases[11] = [0];
        // head
        rarities[12] = [70, 150, 100, 100, 100];
        aliases[12] = [2, 4, 1, 3, 2];

        rarities[13] = [255];
        aliases[13] = [0];

        // weapons
        rarities[14] = [
            200,
            220,
            100,
            234,
            234,
            150,
            180,
            140,
            150,
            120,
            200,
            160
        ];
        aliases[14] = [1, 3, 9, 0, 10, 8, 8, 4, 1, 0, 6, 8];
        // clothing    12039 >> 8 =
        rarities[15] = [140, 130, 165, 120, 100, 150, 160, 100];
        aliases[15] = [1, 4, 0, 6, 2, 3, 5, 3];
        // feet
        rarities[16] = [255];
        aliases[16] = [0];
        // divinityIndex
        // halos
        rarities[17] = [8, 160, 73, 255];
        aliases[17] = [2, 3, 3, 3];
    }

    /** EXTERNAL */

    /**
     * mint a token - 90% Worshippers, 10% Gods
     * The first 20% are free to claim, the remaining cost $FAITH
     */
    function mint(uint256 amount, bool stake) external payable whenNotPaused {
        require(tx.origin == _msgSender(), "Only EOA");
        require(minted + amount <= MAX_TOKENS, "All tokens minted");
        require(amount > 0 && amount <= 50, "Invalid mint amount");
        if (minted < PAID_TOKENS) {
            require(
                minted + amount <= PAID_TOKENS,
                "All tokens on-sale already sold"
            ); 
            require(amount * MINT_PRICE == msg.value, "Invalid payment amount");
        } else {
            require(msg.value == 0);
        }

        uint256 totalFaithCost = 0;
        uint16[] memory tokenIds = stake
            ? new uint16[](amount)
            : new uint16[](0);
        uint256 seed;
        for (uint256 i = 0; i < amount; i++) {
            minted++;
            seed = random(minted);
            generate(minted, seed);
            address recipient = selectRecipient(seed);
            if (!stake || recipient != _msgSender()) {
                _safeMint(recipient, minted);
            } else {
                _safeMint(address(temple), minted);
                tokenIds[i] = minted;
            }
            totalFaithCost += mintCost(minted);
        }

        if (totalFaithCost > 0) faith.burn(_msgSender(), totalFaithCost);
        if (stake) temple.addManyToTempleAndPantheon(_msgSender(), tokenIds);
    }

    /**
     * the first 20% are paid in ETH
     * the next 20% are 20000 $FAITH
     * the next 40% are 40000 $FAITH
     * the final 20% are 80000 $FAITH
     * @param tokenId the ID to check the cost of to mint
     * @return the cost of the given token ID
     */
    function mintCost(uint256 tokenId) public view returns (uint256) {
        if (tokenId <= PAID_TOKENS) return 0;
        if (tokenId <= (MAX_TOKENS * 2) / 5) return 20000 ether;
        if (tokenId <= (MAX_TOKENS * 4) / 5) return 40000 ether;
        return 80000 ether;
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        // Hardcode the Temple's approval so that users don't have to waste gas approving
        if (_msgSender() != address(temple))
            require(
                _isApprovedOrOwner(_msgSender(), tokenId),
                "ERC721: transfer caller is not owner nor approved"
            );
        _transfer(from, to, tokenId);
    }


    /** INTERNAL */

    /**
     * generates traits for a specific token, checking to make sure it's unique
     * @param tokenId the id of the token to generate traits for
     * @param seed a pseudorandom 256 bit number to derive traits from
     * @return t - a struct of traits for the given token ID
     */
    function generate(uint256 tokenId, uint256 seed)
        internal
        returns (WorshipperGod memory t)
    {
        t = selectTraits(seed);
        if (existingCombinations[structToHash(t)] == 0) {
            tokenTraits[tokenId] = t;
            existingCombinations[structToHash(t)] = tokenId;
            return t;
        }
        return generate(tokenId, random(seed));
    }

    /**
     * uses A.J. Walker's Alias algorithm for O(1) rarity table lookup
     * ensuring O(1) instead of O(n) reduces mint cost by more than 50%
     * probability & alias tables are generated off-chain beforehand
     * @param seed portion of the 256 bit seed to remove trait correlation
     * @param traitType the trait type to select a trait for
     * @return the ID of the randomly selected trait
     */
    function selectTrait(uint16 seed, uint8 traitType)
        internal
        view
        returns (uint8)
    {
        uint8 trait = uint8(seed) % uint8(rarities[traitType].length); // seed value is mod'd to fit within length of rarities length
                                                                    // uint16 has a max value of 65535 so seed can be any value between 0 and 65535
                                                                    // shift operator '>>' works as follows x>>y becomes x / (2 ^ y)
                                                                    // 65535 turns into 255.99 or 255 integer the max value of the uint8 and max value in traits array
        if (seed >> 8 < rarities[traitType][trait]) return trait; // seed is shifted with 8 (2^8 or 8 bit) then checks if number 
                                                                 //that corresponds to rarity is less than that new seed value
                                                                 // ex. if the seed = 21239 new seed = 82.9 or 82 which would then check with the traits array
                                                                 // therefore, the larger the value in the trait array, the more likely it is to be picked
                                                                 // if the value is smaller it goes to the alias to pick
                                                                 // not all indeces have to be present in the alias array
                                                                 // as it is picking up only on the traits the random seed does not return with after the shift
                                                                 //if not the trait selected will use the alias array to pick the traits
                                                                 // therefore if trait index is not in the alias array it makes it more rare
                                                                 // this is why the alias array has to hold numbers that fit between the length of their trait data
                                                                 // which also means alias and rarities arrays haave to be of equal length as well
        return aliases[traitType][trait];
    }

    /**
     * sets stealing mechanic
     * @param steal to set stealing mechanic
     */
     function enableSteal (bool steal) external onlyOwner{
         setSteal = steal;
     }

    /**
     * the first 20% (ETH purchases) go to the minter
     * the remaining 80% have a 10% chance to be given to a random staked wolf
     * @param seed a random value to select a recipient from
     * @return the address of the recipient (either the minter or the Wolf thief's owner)
     */
    function selectRecipient(uint256 seed) internal view returns (address) {
        if (minted <= PAID_TOKENS || ((seed >> 245) % 10) != 0)
            return _msgSender(); // top 10 bits haven't been used
        address thief = temple.randomGodOwner(seed >> 144); // 144 bits reserved for trait selection
        if (thief == address(0x0)) return _msgSender();
        if(setSteal){ // if steal is turned on then thief can be chosen
            return thief;
        } // else return the minter
        return  _msgSender();
    }

    /**
     * selects the species and all of its traits based on the seed value
     * @param seed a pseudorandom 256 bit number to derive traits from
     * @return t -  a struct of randomly selected traits
     */
    function selectTraits(uint256 seed)
        internal
        view
        returns (WorshipperGod memory t)
    {
        t.isWorshipper = (seed & 0xFFFF) % 10 != 0;
        uint8 shift = t.isWorshipper ? 0 : 9;
        seed >>= 16;
        // seed divided by 65536
        // 0xFFFF is 65535

        t.tone = selectTrait(uint16(seed & 0xFFFF), 0 + shift);
        seed >>= 16;
        t.head = selectTrait(uint16(seed & 0xFFFF), 1 + shift);
        seed >>= 16;
        t.clothes = selectTrait(uint16(seed & 0xFFFF), 2 + shift);
        seed >>= 16;
        t.eyes = selectTrait(uint16(seed & 0xFFFF), 3 + shift);
        seed >>= 16;
        t.nose = selectTrait(uint16(seed & 0xFFFF), 4 + shift);
        seed >>= 16;
        t.beard = selectTrait(uint16(seed & 0xFFFF), 5 + shift);
        seed >>= 16;
        t.mouth = selectTrait(uint16(seed & 0xFFFF), 6 + shift);
        seed >>= 16;
        t.feet = selectTrait(uint16(seed & 0xFFFF), 7 + shift);
        seed >>= 16;
        t.divinityIndex = selectTrait(uint16(seed & 0xFFFF), 8 + shift);
    }

    /**
     * converts a struct to a 256 bit hash to check for uniqueness
     * @param s the struct to pack into a hash
     * @return the 256 bit hash of the struct
     */
    function structToHash(WorshipperGod memory s)
        internal
        pure
        returns (uint256)
    {
        return
            uint256(
                bytes32(
                    abi.encodePacked(
                        s.isWorshipper,
                        s.tone,
                        s.head,
                        s.eyes,
                        s.mouth,
                        s.beard,
                        s.clothes,
                        s.feet,
                        s.divinityIndex
                    )
                )
            );
    }

    /**
     * generates a pseudorandom number
     * @param seed a value ensure different outcomes for different sources in the same block
     * @return a pseudorandom value
     */
    function random(uint256 seed) internal view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        tx.origin,
                        blockhash(block.number - 1),
                        block.timestamp,
                        seed
                    )
                )
            );
    }

    /** READ */

    function getTokenTraits(uint256 tokenId)
        external
        view
        override
        returns (WorshipperGod memory)
    {
        return tokenTraits[tokenId];
    }

    function getPaidTokens() external view override returns (uint256) {
        return PAID_TOKENS;
    }

    /** ADMIN */

    /**
     * called after deployment so that the contract can get random wolf thieves
     * @param _temple the address of the Barn
     */
    function setTemple(address _temple) external onlyOwner {
        temple = ITemple(_temple);
    }

    /**
     * allows owner to withdraw funds from minting
     */
    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    /**
     * updates the number of tokens for sale
     */
    function setPaidTokens(uint256 _paidTokens) external onlyOwner {
        PAID_TOKENS = _paidTokens;
    }

    /**
     * enables owner to pause / unpause minting
     */
    function setPaused(bool _paused) external onlyOwner {
        if (_paused) _pause();
        else _unpause();
    }

    /** RENDER */

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        return traits.tokenURI(tokenId);
    }
}
