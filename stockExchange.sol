pragma solidity ^0.4.11;

contract Owned {
    address public owner;

    function setOwner(address _owner) onlyOwner
    { owner = _owner; }

    modifier onlyOwner { require(msg.sender == owner); _; }
}

contract Destroyable {
    address public hammer;

    function setHammer(address _hammer) onlyHammer
    { hammer = _hammer; }

    function destroy() onlyHammer
    { suicide(msg.sender); }

    modifier onlyHammer { require(msg.sender == hammer); _; }
}

contract StockExchange is Owned, Destroyable {

    struct Order {
        address creator;
        uint amount;
        uint leverage;
        int8 factor;
        uint rate;
    }


    uint public rate = 1.0e9;

    mapping(uint => Order) public orders;

    uint public lastOrderId = 0;

    function StockExchange(){
        owner  = msg.sender;
        hammer = msg.sender;
    }

    function createOrder(uint leverage, int8 factor) validateLeverage(leverage) validateFactor(factor) validateOrderValue() payable {
        lastOrderId = lastOrderId + 1;
        orders[lastOrderId] = Order({
            creator : msg.sender,
            amount  : msg.value,
            leverage: leverage,
            factor  : factor,
            rate    : rate
        });
    }

    function cancelOrder(uint orderId) {
        require(msg.sender == owner || msg.sender == orders[orderId].creator);
        delete orders[orderId];
    }

    ///should be multiplied by rateMultiplier
    function updateRate(uint _rate) adminOnly {
        rate = _rate;
    }

    modifier adminOnly() {
        require(msg.sender == owner);
        _; 
    }
    
    modifier validateLeverage(uint _leverage){
        require(true);
        _;
    }
    
    modifier validateFactor(int8 _factor){
        require(_factor == -1 || _factor == 1);
        _;
    }

    modifier validateOrderValue(){
        require(msg.value > 0);
        _;
    }
}
