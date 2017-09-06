pragma solidity ^0.4.11;

import './oraclizeAPI.sol';

contract Object {
    address public owner;

    function Object() {
        owner = msg.sender;
    }

    function setOwner(address _owner) onlyOwner() {
        owner = _owner;
    }

    function destroy() onlyOwner() {
        selfdestruct(msg.sender);
    }

    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }
}

contract StockExchange is Object, usingOraclize {

    struct Order {
        address creator;
        uint248 amount;
        uint248 leverage;
        bool factor;
        uint248 rate;
        bool closed;
    }

    Order[] public orders;

    uint248 public rate = 0;

    string private url = '';

    mapping(bytes32 => bool) public queriesQueue;
    
    bool updaterIsRunning = false;

    event OrderCreated(
        uint    orderId,
        address creator,
        uint248 amount,
        uint248 leverage,
        bool    factor,
        uint248 openRate
    );
    event OrderClosed(
        uint    orderId,
        address creator,
        uint248 creationAmount,
        uint248 closingAmount,
        uint248 leverage,
        bool    factor,
        uint248 creationRate,
        uint248 closingRate,
        string  initiator
    );
    event RateUpdated(string newRate, bytes32 queryId);
    event UpdaterStatusUpdated(string status);

    function() payable {
        if(!updaterIsRunning && bytes(url).length != 0){
            updaterIsRunning = true;
            UpdaterStatusUpdated('running');
            updateRate();
        }
    }

    function setUrl(string _url) internal {
        url = _url;
    }

    //factor: true for buying | false for selling
    function openOrder(uint248 leverage, bool factor) payable {
        require(rate != 0);
        require(msg.value > 0);
        require(leverage >= 1 && leverage <= 100);

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

    function updateRate() internal {
        if(oraclize_getPrice("URL") < this.balance){
            bytes32 queryId = oraclize_query(60, "URL", url);
            queriesQueue[queryId] = false;
        } else {
            updaterIsRunning = false;
            UpdaterStatusUpdated('stopped');
        }
    }

    function __callback(bytes32 queryId, string result) {
        require(msg.sender == oraclize_cbAddress());
        if(queriesQueue[queryId]){
            return;
        }
        rate = uint248(parseInt(result, 9));
        queriesQueue[queryId] = true;
        RateUpdated(result, queryId);
        for(uint i = 0; i < orders.length; i++){
           if(!orders[i].closed){
               int256 resultAmount = calculateAmount(orders[i]);
               if(resultAmount <= 0){
                   processOrderClosing(i, resultAmount, 'contract');
               }
           }
        }
        updateRate();
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
        int256 delta = int256(order.leverage) *  int256(rate - order.rate) * int256(order.amount) / int256(order.rate) ;
        return order.factor ? (order.amount + delta) : (order.amount - delta);
    }
}
