// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./libraries/ERC721.sol";
import "./libraries/ERC721Enumerable.sol";
import "./uniswapv2/interfaces/IUniswapV2Pair.sol";
import "./interfaces/IERC1271.sol";
import "./interfaces/IGachaHousekeeper.sol";
import "./libraries/Signature.sol";
import "./libraries/RandomPower.sol";

contract GachaHousekeeper is Ownable, ERC721("MaidCoin Gacha Housekeepers", "GHSKP"), ERC721Enumerable, IGachaHousekeeper {
    struct GachaHousekeeperInfo {
        uint256 originPower;
        uint256 supportedLPTokenAmount;
        uint256 sushiRewardDebt;
        uint256 destroyReturn;
    }

    bytes32 private immutable _CACHED_DOMAIN_SEPARATOR;
    uint256 private immutable _CACHED_CHAIN_ID;

    bytes32 private immutable _HASHED_NAME;
    bytes32 private immutable _HASHED_VERSION;
    bytes32 private immutable _TYPE_HASH;

    // keccak256("Permit(address spender,uint256 tokenId,uint256 nonce,uint256 deadline)");
    bytes32 public constant override PERMIT_TYPEHASH =
        0x49ecf333e5b8c95c40fdafc95c1ad136e8914a8fb55e9dc8bb01eaa83a2df9ad;

    // keccak256("Permit(address owner,address spender,uint256 nonce,uint256 deadline)");
    bytes32 public constant override PERMIT_ALL_TYPEHASH =
        0xdaab21af31ece73a508939fedd476a5ee5129a5ed4bb091f3236ffb45394df62;

    mapping(uint256 => uint256) public override nonces;
    mapping(address => uint256) public override noncesForAll;

    IMaidCoin public immutable override maidCoin;
    IUniswapV2Pair public immutable override lpToken;
    IRNG public override rng;

    uint256 public override lpTokenToHousekeeperPower = 1;
    uint256 public override mintPrice = 1 * 1e18;
    uint256 public override destroyReturn = (mintPrice * 10) / 100;

    IERC20 public immutable override sushi;
    IMasterChef public override sushiMasterChef;
    uint256 public override pid;
    uint256 public override sushiLastRewardBlock;
    uint256 public override accSushiPerShare;
    bool private initialDeposited;

    GachaHousekeeperInfo[] public override housekeepers;

    constructor(
        IMaidCoin _maidCoin,
        IUniswapV2Pair _lpToken,
        IRNG _rng,
        IERC20 _sushi
    ) {
        maidCoin = _maidCoin;
        lpToken = _lpToken;
        rng = _rng;
        sushi = _sushi;

        _CACHED_CHAIN_ID = block.chainid;
        _HASHED_NAME = keccak256(bytes("MaidCoin Gacha Housekeepers"));
        _HASHED_VERSION = keccak256(bytes("1"));
        _TYPE_HASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

        _CACHED_DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("MaidCoin Gacha Housekeepers")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://api.maidcoin.org/gachahousekeepers/";
    }

    function DOMAIN_SEPARATOR() public view override returns (bytes32) {
        if (block.chainid == _CACHED_CHAIN_ID) {
            return _CACHED_DOMAIN_SEPARATOR;
        } else {
            return keccak256(abi.encode(_TYPE_HASH, _HASHED_NAME, _HASHED_VERSION, block.chainid, address(this)));
        }
    }

    function changeLPTokenToHousekeeperPower(uint256 value) external onlyOwner {
        lpTokenToHousekeeperPower = value;
        emit ChangeLPTokenToHousekeeperPower(value);
    }

    function changePrice(uint256 _mintPrice, uint256 _destroyReturn) external onlyOwner {
        mintPrice = _mintPrice;
        destroyReturn = _destroyReturn;
        emit ChangePrice(_mintPrice, _destroyReturn);
    }

    function powerOf(uint256 id) external view override returns (uint256) {
        GachaHousekeeperInfo storage housekeeper = housekeepers[id];
        return housekeeper.originPower + (housekeeper.supportedLPTokenAmount * lpTokenToHousekeeperPower) / 1e18;
    }

    function support(uint256 id, uint256 lpTokenAmount) public override {
        require(ownerOf(id) == msg.sender, "GachaHousekeeper: Forbidden");
        require(lpTokenAmount > 0, "GachaHousekeeper: Invalid lpTokenAmount");

        uint256 _supportedLPTokenAmount = housekeepers[id].supportedLPTokenAmount;

        housekeepers[id].supportedLPTokenAmount = _supportedLPTokenAmount + lpTokenAmount;
        lpToken.transferFrom(msg.sender, address(this), lpTokenAmount);

        uint256 _pid = pid;
        if (_pid > 0) {
            uint256 _totalSupportedLPTokenAmount = sushiMasterChef.userInfo(_pid, address(this)).amount;
            uint256 _accSushiPerShare = _depositToSushiMasterChef(_pid, lpTokenAmount, _totalSupportedLPTokenAmount);
            uint256 pending = (_supportedLPTokenAmount * _accSushiPerShare) / 1e18 - housekeepers[id].sushiRewardDebt;
            if (pending > 0) safeSushiTransfer(msg.sender, pending);
            housekeepers[id].sushiRewardDebt = ((_supportedLPTokenAmount + lpTokenAmount) * _accSushiPerShare) / 1e18;
        }

        emit Support(id, lpTokenAmount);
    }

    function supportWithPermit(
        uint256 id,
        uint256 lpTokenAmount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        lpToken.permit(msg.sender, address(this), lpTokenAmount, deadline, v, r, s);
        support(id, lpTokenAmount);
    }

    function desupport(uint256 id, uint256 lpTokenAmount) external override {
        require(ownerOf(id) == msg.sender, "GachaHousekeeper: Forbidden");

        require(lpTokenAmount > 0, "GachaHousekeeper: Invalid lpTokenAmount");
        uint256 _supportedLPTokenAmount = housekeepers[id].supportedLPTokenAmount;

        housekeepers[id].supportedLPTokenAmount = _supportedLPTokenAmount - lpTokenAmount;

        uint256 _pid = pid;
        if (_pid > 0) {
            uint256 _totalSupportedLPTokenAmount = sushiMasterChef.userInfo(_pid, address(this)).amount;
            uint256 _accSushiPerShare = _withdrawFromSushiMasterChef(_pid, lpTokenAmount, _totalSupportedLPTokenAmount);
            uint256 pending = (_supportedLPTokenAmount * _accSushiPerShare) / 1e18 - housekeepers[id].sushiRewardDebt;
            if (pending > 0) safeSushiTransfer(msg.sender, pending);
            housekeepers[id].sushiRewardDebt = ((_supportedLPTokenAmount - lpTokenAmount) * _accSushiPerShare) / 1e18;
        }

        lpToken.transfer(msg.sender, lpTokenAmount);
        emit Desupport(id, lpTokenAmount);
    }

    function claimSushiReward(uint256 id) public override {
        require(ownerOf(id) == msg.sender, "GachaHousekeeper: Forbidden");
        uint256 _pid = pid;
        require(_pid > 0, "GachaHousekeeper: Unclaimable");
        uint256 _supportedLPTokenAmount = housekeepers[id].supportedLPTokenAmount;

        uint256 _totalSupportedLPTokenAmount = sushiMasterChef.userInfo(_pid, address(this)).amount;
        uint256 _accSushiPerShare = _depositToSushiMasterChef(_pid, 0, _totalSupportedLPTokenAmount);
        uint256 pending = (_supportedLPTokenAmount * _accSushiPerShare) / 1e18 - housekeepers[id].sushiRewardDebt;
        require(pending > 0, "GachaHousekeeper: Nothing can be claimed");
        safeSushiTransfer(msg.sender, pending);
        housekeepers[id].sushiRewardDebt = (_supportedLPTokenAmount * _accSushiPerShare) / 1e18;
    }

    function pendingSushiReward(uint256 id) external view override returns (uint256) {
        uint256 _pid = pid;
        if (_pid == 0) return 0;
        uint256 _supportedLPTokenAmount = housekeepers[id].supportedLPTokenAmount;
        uint256 _totalSupportedLPTokenAmount = sushiMasterChef.userInfo(_pid, address(this)).amount;

        uint256 _accSushiPerShare = accSushiPerShare;
        if (block.number > sushiLastRewardBlock && _totalSupportedLPTokenAmount != 0) {
            uint256 reward = sushiMasterChef.pendingSushi(pid, address(this));
            _accSushiPerShare += ((reward * 1e18) / _totalSupportedLPTokenAmount);
        }

        return (_supportedLPTokenAmount * _accSushiPerShare) / 1e18 - housekeepers[id].sushiRewardDebt;
    }

    function permit(
        address spender,
        uint256 id,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        require(block.timestamp <= deadline, "GachaHousekeeper: Expired deadline");
        bytes32 _DOMAIN_SEPARATOR = DOMAIN_SEPARATOR();

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                _DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, spender, id, nonces[id], deadline))
            )
        );
        nonces[id] += 1;

        address owner = ownerOf(id);
        require(spender != owner, "GachaHousekeeper: Invalid spender");

        if (Address.isContract(owner)) {
            require(
                IERC1271(owner).isValidSignature(digest, abi.encodePacked(r, s, v)) == 0x1626ba7e,
                "GachaHousekeeper: Unauthorized"
            );
        } else {
            address recoveredAddress = Signature.recover(digest, v, r, s);
            require(recoveredAddress == owner, "GachaHousekeeper: Unauthorized");
        }

        _approve(spender, id);
    }

    function permitAll(
        address owner,
        address spender,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        require(block.timestamp <= deadline, "GachaHousekeeper: Expired deadline");
        bytes32 _DOMAIN_SEPARATOR = DOMAIN_SEPARATOR();

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                _DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_ALL_TYPEHASH, owner, spender, noncesForAll[owner], deadline))
            )
        );
        noncesForAll[owner] += 1;

        if (Address.isContract(owner)) {
            require(
                IERC1271(owner).isValidSignature(digest, abi.encodePacked(r, s, v)) == 0x1626ba7e,
                "GachaHousekeeper: Unauthorized"
            );
        } else {
            address recoveredAddress = Signature.recover(digest, v, r, s);
            require(recoveredAddress == owner, "GachaHousekeeper: Unauthorized");
        }

        _setApprovalForAll(owner, spender, true);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, IERC165)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function mint() public override returns (uint256 id) {
        id = housekeepers.length;
        maidCoin.transferFrom(msg.sender, address(this), mintPrice);
        uint256 prePower = (rng.generateRandomNumber(id, msg.sender) % 4950) + 1;
        housekeepers.push(
            GachaHousekeeperInfo({
                originPower: RandomPower.findPower(prePower),
                supportedLPTokenAmount: 0,
                sushiRewardDebt: 0,
                destroyReturn: destroyReturn
            })
        );
        _mint(msg.sender, id);
    }

    function mintWithPermit(
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override returns (uint256 id) {
        maidCoin.permit(msg.sender, address(this), mintPrice, deadline, v, r, s);
        return mint();
    }

    function destroy(uint256 id) external override {
        require(msg.sender == ownerOf(id), "GachaHousekeeper: Forbidden");
        maidCoin.transfer(msg.sender, destroyReturn);
        _burn(id);
    }

    function setSushiMasterChef(IMasterChef _masterChef, uint256 _pid) external override onlyOwner {
        require(address(_masterChef.poolInfo(_pid).lpToken) == address(lpToken), "GachaHousekeeper: Invalid pid");
        if (!initialDeposited) {
            initialDeposited = true;
            lpToken.approve(address(_masterChef), type(uint256).max);

            sushiMasterChef = _masterChef;
            pid = _pid;
            _depositToSushiMasterChef(_pid, lpToken.balanceOf(address(this)), 0);
        } else {
            IMasterChef oldChef = sushiMasterChef;
            uint256 oldpid = pid;
            _withdrawFromSushiMasterChef(oldpid, oldChef.userInfo(oldpid, address(this)).amount, 0);
            if (_masterChef != oldChef) {
                lpToken.approve(address(oldChef), 0);
                lpToken.approve(address(_masterChef), type(uint256).max);
            }

            sushiMasterChef = _masterChef;
            pid = _pid;
            _depositToSushiMasterChef(_pid, lpToken.balanceOf(address(this)), 0);
        }
    }

    function _depositToSushiMasterChef(
        uint256 _pid,
        uint256 _amount,
        uint256 _totalSupportedLPTokenAmount
    ) internal returns (uint256 _accSushiPerShare) {
        return _toSushiMasterChef(true, _pid, _amount, _totalSupportedLPTokenAmount);
    }

    function _withdrawFromSushiMasterChef(
        uint256 _pid,
        uint256 _amount,
        uint256 _totalSupportedLPTokenAmount
    ) internal returns (uint256 _accSushiPerShare) {
        return _toSushiMasterChef(false, _pid, _amount, _totalSupportedLPTokenAmount);
    }

    function _toSushiMasterChef(
        bool deposit,
        uint256 _pid,
        uint256 _amount,
        uint256 _totalSupportedLPTokenAmount
    ) internal returns (uint256) {
        uint256 reward;
        if (block.number <= sushiLastRewardBlock) {
            if (deposit) sushiMasterChef.deposit(_pid, _amount);
            else sushiMasterChef.withdraw(_pid, _amount);
            return accSushiPerShare;
        } else {
            uint256 balance0 = sushi.balanceOf(address(this));
            if (deposit) sushiMasterChef.deposit(_pid, _amount);
            else sushiMasterChef.withdraw(_pid, _amount);
            uint256 balance1 = sushi.balanceOf(address(this));
            reward = balance1 - balance0;
        }
        sushiLastRewardBlock = block.number;
        if (_totalSupportedLPTokenAmount > 0 && reward > 0) {
            uint256 _accSushiPerShare = accSushiPerShare + ((reward * 1e18) / _totalSupportedLPTokenAmount);
            accSushiPerShare = _accSushiPerShare;
            return _accSushiPerShare;
        } else {
            return accSushiPerShare;
        }
    }

    function safeSushiTransfer(address _to, uint256 _amount) internal {
        uint256 sushiBal = sushi.balanceOf(address(this));
        if (_amount > sushiBal) {
            sushi.transfer(_to, sushiBal);
        } else {
            sushi.transfer(_to, _amount);
        }
    }
}
