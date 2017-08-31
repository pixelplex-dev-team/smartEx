pragma solidity ^0.4.11;

contract Object {
    address public owner;

    function Object() {
        owner = msg.sender;
    }

    function setOwner(address _owner) onlyOwner() {
        owner = _owner;
    }

    function destroy() onlyOwner() {
        suicide(msg.sender);
    }

    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }
}

contract StockExchange is Object {

    struct Order {
        address creator;
        uint248 amount;
        uint248 leverage;
        bool factor;
        uint248 rate;
        bool closed;
    }

    Order[] public orders;

    uint248 public rate = 1.0e9;

    event OrderCreated(
        uint orderId,
        address creator,
        uint248 amount,
        uint248 leverage,
        bool factor,
        uint248 rate
    );
    event OrderClosed(
        uint orderId,
        address creator,
        uint248 creationAmount,
        uint248 closingAmount,
        uint248 leverage,
        bool factor,
        uint248 creationRate,
        uint248 closingRate,
        string initiator
    );

    //factor: true for buying | false for selling
    function openOrder(uint248 leverage, bool factor) validateLeverage(leverage) validateOrderValue() payable {
        uint orderId = orders.length;
        orders.push(Order({
            creator : msg.sender,
            amount  : uint248(msg.value),
            leverage: leverage,
            factor  : factor,
            rate    : rate,
            closed  : false
        }));
        OrderCreated(
            orderId,
            msg.sender,
            uint248(msg.value),
            leverage,
            factor,
            rate
        );
    }

    function closeOrder(uint orderId) {
        require(msg.sender == owner || msg.sender == orders[orderId].creator);
        require(!orders[orderId].closed);

        int256 resultAmount = calculateAmount(orders[orderId]);
        if(resultAmount > 0){
            orders[orderId].creator.transfer(uint256(resultAmount));
        }
        processOrderClosing(orderId, resultAmount, msg.sender == orders[orderId].creator ? 'trader' : 'admin');
    }

    ///should be multiplied by rateMultiplier
    function updateRate(uint248 _rate) onlyOwner() {
        rate = _rate;
        for(uint i = 0; i < orders.length; i++){
           if(!orders[i].closed){
               int256 resultAmount = calculateAmount(orders[i]);
               if(!(resultAmount > 0)){
                   processOrderClosing(i, resultAmount, 'contract');
               }
           } 
        }
    }

    function processOrderClosing(uint orderId, int256 resultAmount, string initiator) internal {
        orders[orderId].closed = true;

        OrderClosed(
            orderId,
            orders[orderId].creator,
            uint248(orders[orderId].amount),
            resultAmount > 0 ? uint248(resultAmount) : 0,
            orders[orderId].leverage,
            orders[orderId].factor,
            orders[orderId].rate,
            rate,
            initiator
        );
    }

    function calculateAmount(Order order) internal returns(int256) {
        int256 delta =  int256(rate - order.rate) * int256(order.amount) / int256(order.rate) * int256(order.leverage) ;
        return order.factor ? (order.amount + delta) : (order.amount - delta);
    }

    modifier validateLeverage(uint248 _leverage){
        require(true);
        _;
    }
    
    modifier validateOrderValue(){
        require(msg.value > 0);
        _;
    }

    function() payable {}
}
