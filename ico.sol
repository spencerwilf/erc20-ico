// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface ERC20Interface {
    function totalSupply() external view returns (uint);
    function balanceOf(address tokenOwner) external view returns (uint balance);
    function transfer(address to, uint tokens) external returns (bool success);
    
    function allowance(address tokenOwner, address spender) external view returns (uint remaining);
    function approve(address spender, uint tokens) external returns (bool success);
    function transferFrom(address from, address to, uint tokens) external returns (bool success);
    
    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

contract SpenceCoin is ERC20Interface {
    string public name = "SpenceCoin";
    string public symbol = "SPC";
    uint public decimals = 0;
    uint public override totalSupply;

    mapping(address => mapping (address => uint)) public allowed;

    address public owner;
    mapping(address => uint) public balances;

    constructor() {
        totalSupply = 1000000;
        owner = msg.sender;
        balances[owner] = totalSupply;
    }

    function balanceOf(address tokenOwner) public view override returns (uint balance) {
        return balances[tokenOwner];
    }

    function transfer(address to, uint tokens) public virtual override returns(bool) {
        require(balances[msg.sender] >= tokens);
        balances[to] += tokens;
        balances[msg.sender] -= tokens;
        emit Transfer(msg.sender, to, tokens);
        return true;
    }

    function allowance(address tokenOwner, address spender) view public override returns(uint) {
        return allowed[tokenOwner][spender];
    }

     function approve(address spender, uint tokens) public override returns (bool success) {
         require(balances[msg.sender] >= tokens);
         require(tokens > 0);

         allowed[msg.sender][spender] = tokens;
         emit Approval(msg.sender, spender, tokens);
         return true;
     }

     function transferFrom(address from, address to, uint tokens) public virtual override returns (bool success) {
         require(allowed[from][msg.sender] >= tokens);
         require(balances[from] >= tokens);
         balances[from] -= tokens;
         allowed[from][msg.sender] -= tokens;
         balances[to] += tokens;
         emit Transfer(from, to, tokens);
        return true;
     }

}

contract SpenceICO is SpenceCoin {

    address public admin;
    address payable public deposit;
    uint public constant TOKEN_PRICE = 0.001 ether;
    uint public constant HARDCAP = 300 ether;
    uint public raisedAmount;
    uint public saleStart = block.timestamp;
    uint public saleEnd = block.timestamp + 604800;
    uint public tradeStart = saleEnd + 604800;
    uint public constant MAX_INVESTMENT = 5 ether;
    uint public constant MIN_INVESTMENT = 0.1 ether;
    enum State { beforeStart, running, afterEnd, halted }
    State public icoState;

    event Invest(address investor, uint value, uint tokens);

    constructor(address payable _deposit) {
        deposit = _deposit;
        admin = msg.sender;
        icoState = State.beforeStart;
    }

    function halt() public onlyAdmin {
        icoState = State.halted;
    }

    function resume() public onlyAdmin {
        icoState = State.running;
    }

    function changeDepositAddress(address payable newAddress) public onlyAdmin {
        deposit = newAddress;
    }

    function getCurrentState() public view returns(State){
        if(icoState == State.halted){
            return State.halted;
        }else if(block.timestamp < saleStart){
            return State.beforeStart;
        }else if(block.timestamp >= saleStart && block.timestamp <= saleEnd){
            return State.running;
        }else{
            return State.afterEnd;
        }
    }

    function invest() payable public returns(bool) {
        icoState = getCurrentState();
        require(icoState == State.running);
        require(msg.value >= MIN_INVESTMENT && msg.value <= MAX_INVESTMENT);
        raisedAmount += msg.value;
        require(raisedAmount <= HARDCAP);

        uint tokens = msg.value / TOKEN_PRICE;

        balances[msg.sender] += tokens;
        balances[admin] -= tokens;

        deposit.transfer(msg.value);
        emit Invest(msg.sender, msg.value, tokens);
        return true;
    }

    function transfer(address to, uint tokens) public override returns(bool) {
        require(block.timestamp > tradeStart);
        super.transfer(to, tokens);
        return true;
    }

    function transferFrom(address from, address to, uint tokens) public override returns (bool success) {
        require(block.timestamp > tradeStart);
        super.transferFrom(from, to, tokens);
        return true;
    }

    function burn() public returns(bool) {
        icoState = getCurrentState();
        require(icoState == State.afterEnd);
        balances[admin] = 0;
        return true;
    }

    receive() payable external {
        invest();
    }

    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }
}