// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./SafeMath.sol";
import "./Ownable.sol";
import "./ERC721Enumerable.sol";



abstract contract JungleStorage {
    uint256 public startingIndexBlock;
    uint256 public tokenPrice = 0.0000094 ether; 
    uint256 public accumulationRate = 1.36986 ether;
    uint256 public startingIndex;
    uint256 public emissionEnd = 86400 * 365 ;
    uint256 public tokensForPublic = 5000000 ether;
    uint256 public tokensForPublicAccrued=5000000 ether;
    uint256 public tokensForTeams = 500000 ether;
    uint256 public tokensForTeamsAfter365 =500000 ether;
    uint256 public SECONDS_IN_A_DAY = 86400;
    uint256 internal _totalSupply;

    string internal _name;
    string internal _symbol;
    address public cardAddress;
    uint8 internal _decimals;
    
    mapping (address => uint256) internal _balances;
    mapping (address => mapping (address => uint256)) internal _allowances;
    mapping (uint256 => uint256) public _lastClaim;
    mapping (uint256 => uint256) public emissionStart;
    
}
contract JungleToken is IERC20,Ownable,JungleStorage {
    using SafeMath for uint256;
    
    event claimedAmount(uint256 claimedAmount);

    
    /**
     * @dev Permissioning not added because it is only callable once.
     */
    function setNftCardAddress(address _cardAddress) onlyOwner public {
        cardAddress = _cardAddress;
    }

    
    /**
     * @dev When accumulated JungleTokens have last been claimed for a NFT index
     */
    function lastClaim(uint256 tokenIndex) public view returns (uint256) {
        require(IERC721Enumerable(cardAddress).ownerOf(tokenIndex) != address(0), "Owner cannot be 0 address");
        require(tokenIndex < IERC721Enumerable(cardAddress).totalSupply(), "NFT at index has not been minted yet");
        uint256 lastClaimed = uint256(_lastClaim[tokenIndex]) != 0 ? uint256(_lastClaim[tokenIndex]) : emissionStart[tokenIndex];
        return lastClaimed;
    }
    
    
    
    /**
     * @dev Claim mints accumulated JungleTokens and supports multiple token indices at once.
     */
    function claim(uint256[] memory tokenIndices) public  returns (uint256) {
        uint256 totalClaimQty = 0;
        for (uint i = 0; i < tokenIndices.length; i++) {
            // Sanity check for non-minted index
            require(tokenIndices[i] < IERC721Enumerable(cardAddress).totalSupply(), "NFT at index has not been minted yet");
            // Duplicate token index check
            for (uint j = i + 1; j < tokenIndices.length; j++) {
                require(tokenIndices[i] != tokenIndices[j], "Duplicate token index");
            }
            uint tokenIndex = tokenIndices[i];
            require(IERC721Enumerable(cardAddress).ownerOf(tokenIndex) != address(0), "Owner cannot be 0 address");

            uint256 lastClaimed = lastClaim(tokenIndex);
            
            require((block.timestamp -(emissionStart[tokenIndex]))>=SECONDS_IN_A_DAY,"Apply after one day to get accumulation amount for this/some token(s)!");
            require(IERC721Enumerable(cardAddress).ownerOf(tokenIndex) == msg.sender, "Sender is not the owner");
            uint256 accumulationPeriod = block.timestamp < emissionStart[tokenIndex].add(emissionEnd) ? block.timestamp : emissionStart[tokenIndex].add(emissionEnd); // Getting the min value of both

            uint256 totalAccumulated = accumulationPeriod.sub(lastClaimed).mul(accumulationRate).div(SECONDS_IN_A_DAY);
            emit claimedAmount(totalAccumulated);
            if (totalAccumulated != 0) {
                totalClaimQty = totalClaimQty.add(totalAccumulated);
                _lastClaim[tokenIndex] = block.timestamp;
            }
        }
        require(totalClaimQty != 0, "No accumulated Jungle tokens");
        mintAccumulationAmt(msg.sender, totalClaimQty); 
        return totalClaimQty;
        }
        
    
    /*
    *Mints accumulation amount when user calls claim(). to "to" address
    */
    function mintAccumulationAmt(address to,uint256 totalClaimQty) private{
        _mint(to, totalClaimQty);
        tokensForPublicAccrued-=totalClaimQty;
    }
    
    /*
    *Mints 500 tokens when user when user calls montNft for buying, Reduces supply by minted amount.
    */
    function mintForPublic(address to,uint256 amount, uint256 mintIndex) external returns(bool){
        require(msg.sender==cardAddress,"You are not authorized to call this function!");
        _mint(to,amount);
        emissionStart[mintIndex] = block.timestamp;
        tokensForPublic-=amount;
        return true;
    }

     
     /**
     * @dev withdrawTokenForTeam sends 500000 token for team to owner address.
     */
     function withdrawTokenForTeam() onlyOwner external {
         require(tokensForTeams!=0,"token for teams already claimed!");
         _mint(msg.sender,tokensForTeams);
         tokensForTeams=0;
     }
     
     /**
     * @dev withdrawTokenForTeamAfterYear sends 500000 jungle tokens to owner address after a year.
     */
     function withdrawTokenForTeamAfterYear() onlyOwner external{
         require(block.timestamp>=emissionEnd,"You can't claim tokens before 1 year completes!");
         require(tokensForTeamsAfter365!=0,"token for teams already claimed!");
         _mint(msg.sender,tokensForTeamsAfter365);
         tokensForTeamsAfter365=0;
     }
    /* 
    *@dev Method for changing price of JungleToken, only callable by owner.
    */
    function changePrice(uint256 newPrice) external onlyOwner {
        require(newPrice> 0,"Price should be greater than zero!");
        tokenPrice=newPrice;
    }
    
    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }
    
    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        // Approval check is skipped if the caller of transferFrom is the NftCard contract. For better UX.
        if (msg.sender != cardAddress) {
            _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        }
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }



    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }
    // ++
    /**
     * @dev Burns a quantity of tokens held by the caller.
     *
     * Emits an {Transfer} event to 0 address
     *
     */
    function burn(address recipient,uint256 burnQuantity) public virtual  returns (bool) {
         require(msg.sender==cardAddress,"You are not authorized to call this function!");
        _burn(recipient, burnQuantity);
        return true;
    }
    
    /** @dev Creates `mintQuantity` tokens and assigns them to `recipient`, increasing
     * the total supply.
     * Emits an {Transfer} event to 0 address
     */
    function mint(address recipient,uint256 mintQuantity) public virtual  returns (bool) {
         require(msg.sender==cardAddress,"You are not authorized to call this function!");
        _mint(recipient, mintQuantity);
        return true;
    }
    // ++

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Sets {decimals} to a value other than the default one of 18.
     *
     * WARNING: This function should only be called from the constructor. Most
     * applications that interact with token contracts will not expect
     * {decimals} to ever change, and may work incorrectly if it does.
     */
    function _setupDecimals(uint8 decimals_) internal {
        _decimals = decimals_;
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }   
    
}
