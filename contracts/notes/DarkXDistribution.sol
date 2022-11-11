// SPDX-License-Identifier: J-J-J-JENGA!!!
pragma solidity ^0.7.4;

import "./IDarkXDistribution.sol";
import "./Owned.sol";
import "./DarkX.sol";
import "./DarkXTransferGate.sol";
import "./TokensRecoverable.sol";
import "./SafeMath.sol";
import "./MATIX.sol";
import "./IERC20.sol";
import "./IUniswapV2Router02.sol";
import "./IUniswapV2Factory.sol";
import "./IUniswapV2Pair.sol";
import "./IWrappedERC20.sol";

/*
Phases:
    Initializing
        Call setupmatiXDarkX() and setupWMIMDarkX()
        Call completeSetup()

    Call distribute() to:
        Transfer all DarkX to this contract
        Take all ETH + DarkX and create a market
        Play jenga
        Buy DarkX
        Buy wMim
        Create DarkX/wMim market
        Buy DarkX for the group
        Distribute funds

    Complete
        Everyone can call claim() to receive their tokens (via the liquidity generation contract)
*/

contract DarkXDistribution is TokensRecoverable, IDarkXDistribution
{
    using SafeMath for uint256;

    bool public override distributionComplete;

    IUniswapV2Router02 immutable uniswapV2Router;
    IUniswapV2Factory immutable uniswapV2Factory;
    DarkX immutable darkX;
    MATIX immutable matiX;
    IERC20 immutable weth;
    IERC20 immutable wMim;
    address immutable vault;

    IUniswapV2Pair matiXDarkX;
    IUniswapV2Pair wMimDarkX;
    IWrappedERC20 wrappedmatiXDarkX;
    IWrappedERC20 wrappedMimDarkX;

    uint256 public totalEthCollected;
    uint256 public totalDarkXBought;
    uint256 public totalWMIMDarkX;
    uint256 public totalmatiXDarkX;
    address darkXLiquidityGeneration;
    uint256 recoveryDate = block.timestamp + 2592000; // 1 Month

    uint8 public jengaCount;

    // 10000 = 100%
    uint16 constant public vaultPercent = 3000; // Proportionate amount used to seed the vault
    uint16 constant public buyPercent = 1000; // Proportionate amount used in presale to buy DarkX for distribution to participants
    uint16 constant public wMimPercent = 3000; // Proportionate amount used to create wMim/DarkX pool

    constructor(DarkX _darkX, IUniswapV2Router02 _uniswapV2Router, MATIX _matiX, IERC20 _wMim, address _vault)
    {
        require (address(_darkX) != address(0));
        require (address(_wMim) != address(0));
        require (address(_vault) != address(0));

        darkX = _darkX;
        uniswapV2Router = _uniswapV2Router;
        matiX = _matiX;
        wMim = _wMim;
        vault = _vault;

        uniswapV2Factory = IUniswapV2Factory(_uniswapV2Router.factory());
        weth = _matiX.wrappedToken();
    }

b     function setupmatiXDarkX() public
    {
        matiXDarkX = IUniswapV2Pair(uniswapV2Factory.getPair(address(matiX), address(darkX)));
        if (address(matiXDarkX) == address(0)) {
            matiXDarkX = IUniswapV2Pair(uniswapV2Factory.createPair(address(matiX), address(darkX)));
            require (address(matiXDarkX) != address(0));
        }
    }
    function setupWMIMDarkX() public
    {
        wMimDarkX = IUniswapV2Pair(uniswapV2Factory.getPair(address(wMim), address(darkX)));
        if (address(wMimDarkX) == address(0)) {
            wMimDarkX = IUniswapV2Pair(uniswapV2Factory.createPair(address(wMim), address(darkX)));
            require (address(wMimDarkX) != address(0));
        }
    }
    function completeSetup(IWrappedERC20 _wrappedmatiXDarkX, IWrappedERC20 _wrappedMimDarkX) public ownerOnly()
    {
        require (address(_wrappedmatiXDarkX.wrappedToken()) == address(matiXDarkX), "Wrong LP Wrapper");
        require (address(_wrappedMimDarkX.wrappedToken()) == address(wMimDarkX), "Wrong LP Wrapper");
        wrappedmatiXDarkX = _wrappedmatiXDarkX;
        wrappedMimDarkX = _wrappedMimDarkX;
        matiX.approve(address(uniswapV2Router), uint256(-1));
        darkX.approve(address(uniswapV2Router), uint256(-1));
        weth.approve(address(matiX), uint256(-1));
        weth.approve(address(uniswapV2Router), uint256(-1));
        wMim.approve(address(uniswapV2Router), uint256(-1));
        matiXDarkX.approve(address(wrappedmatiXDarkX), uint256(-1));
        wMimDarkX.approve(address(wrappedMimDarkX), uint256(-1));
    }

    function setJengaCount(uint8 _jengaCount) public ownerOnly()
    {
        jengaCount = _jengaCount;
    }

    function distribute() public override payable
    {
        require (!distributionComplete, "Distribution complete");
        uint256 totalEth = msg.value;
        require (totalEth > 0, "Nothing to distribute");
        distributionComplete = true;
        totalEthCollected = totalEth;
        darkXLiquidityGeneration = msg.sender;

        darkX.transferFrom(msg.sender, address(this), darkX.totalSupply());

        DarkXTransferGate gate = DarkXTransferGate(address(darkX.transferGate()));
        gate.setUnrestricted(true);

        creatematiXDarkXLiquidity(totalEth);

        jenga(jengaCount);

        sweepFloorToWeth();
        uint256 wethBalance = weth.balanceOf(address(this));

        createWMIMDarkXLiquidity(wethBalance * wMimPercent / 10000);
        preBuyForGroup(wethBalance * buyPercent / 10000);

        sweepFloorToWeth();
        weth.transfer(vault, wethBalance * vaultPercent / 10000);
        weth.transfer(owner, weth.balanceOf(address(this)));
        matiXDarkX.transfer(owner, matiXDarkX.balanceOf(address(this)));

        gate.setUnrestricted(false);
    }

    function sweepFloorToWeth() private
    {
        matiX.sweepFloor(address(this));
        matiX.withdrawTokens(matiX.balanceOf(address(this)));
    }
    function creatematiXDarkXLiquidity(uint256 totalEth) private
    {
        // Create MATIX/ROOT LP
        matiX.deposit{ value: totalEth }();
        (,,totalmatiXDarkX) = uniswapV2Router.addLiquidity(address(matiX), address(darkX), matiX.balanceOf(address(this)), darkX.totalSupply(), 0, 0, address(this), block.timestamp);

        // Wrap the MATIX/ROOT LP for distribution
        wrappedmatiXDarkX.depositTokens(totalmatiXDarkX);
    }
    function createWMIMDarkXLiquidity(uint256 wethAmount) private
    {
        // Buy ROOT with 1/2 of the funds
        address[] memory path = new address[](2);
        path[0] = address(matiX);
        path[1] = address(darkX);
        matiX.depositTokens(wethAmount / 2);
        uint256[] memory amountsDarkX = uniswapV2Router.swapExactTokensForTokens(wethAmount / 2, 0, path, address(this), block.timestamp);

        // Buy wMim with the other 1/2 of the funds
        path[0] = address(weth);
        path[1] = address(wMim);
        uint256[] memory amountsWMIM = uniswapV2Router.swapExactTokensForTokens(wethAmount / 2, 0, path, address(this), block.timestamp);
        (,,totalWMIMDarkX) = uniswapV2Router.addLiquidity(address(wMim), address(darkX), amountsWMIM[1], amountsDarkX[1], 0, 0, address(this), block.timestamp);

        // Wrap the WMIM/ROOT LP for distribution
        wrappedMimDarkX.depositTokens(totalWMIMDarkX);
    }
    function preBuyForGroup(uint256 wethAmount) private
    {
        address[] memory path = new address[](2);
        path[0] = address(matiX);
        path[1] = address(darkX);
        matiX.depositTokens(wethAmount);
        uint256[] memory amountsDarkX = uniswapV2Router.swapExactTokensForTokens(wethAmount, 0, path, address(this), block.timestamp);
        totalDarkXBought = amountsDarkX[1];
    }

    function jenga(uint8 count) private
    {
        address[] memory path = new address[](2);
        path[0] = address(matiX);
        path[1] = address(darkX);
        for (uint x=0; x<count; ++x) {
            matiX.depositTokens(matiX.sweepFloor(address(this)));
            uint256[] memory amounts = uniswapV2Router.swapExactTokensForTokens(matiX.balanceOf(address(this)) * 2 / 5, 0, path, address(this), block.timestamp);
            matiX.depositTokens(matiX.sweepFloor(address(this)));
            uniswapV2Router.addLiquidity(address(matiX), address(darkX), matiX.balanceOf(address(this)), amounts[1], 0, 0, address(this), block.timestamp);
        }
    }

    function claim(address _to, uint256 _contribution) public override
    {
        require (msg.sender == darkXLiquidityGeneration, "Unauthorized");
        uint256 totalEth = totalEthCollected;

        // Send MATIX/ROOT liquidity tokens
        uint256 share = _contribution.mul(totalmatiXDarkX) / totalEth;
        if (share > wrappedmatiXDarkX.balanceOf(address(this))) {
            share = wrappedmatiXDarkX.balanceOf(address(this)); // Should never happen, but just being safe.
        }
        wrappedmatiXDarkX.transfer(_to, share);

        // Send WMIM/ROOT liquidity tokens
        share = _contribution.mul(totalWMIMDarkX) / totalEth;
        if (share > wrappedMimDarkX.balanceOf(address(this))) {
            share = wrappedMimDarkX.balanceOf(address(this)); // Should never happen, but just being safe.
        }
        wrappedMimDarkX.transfer(_to, share);

        // Send DarkX
        DarkXTransferGate gate = DarkXTransferGate(address(darkX.transferGate()));
        gate.setUnrestricted(true);

        share = _contribution.mul(totalDarkXBought) / totalEth;
        if (share > darkX.balanceOf(address(this))) {
            share = darkX.balanceOf(address(this)); // Should never happen, but just being safe.
        }
        darkX.transfer(_to, share);

        gate.setUnrestricted(false);
    }

    function canRecoverTokens(IERC20 token) internal override view returns (bool) {
        return
            block.timestamp > recoveryDate ||
            (
                token != darkX &&
                address(token) != address(wrappedmatiXDarkX) &&
                address(token) != address(wrappedMimDarkX)
            );
    }
}
