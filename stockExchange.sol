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
        suicide(msg.sender);
    }

    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }
}

contract StockExchange is Object, usingOraclize {

    struct Order {
        uint createDate;
        address creator;
        uint248 amount;
        uint248 leverage;
        bool factor;
        uint248 rate;
        bool approved;
        bool closed;
    }

    Order[] public orders;

    uint248 public rate = 0;

    string private url = '';

    mapping(bytes32 => bool) public queriesQueue;
    
    bool updaterIsRunning = false;

    event OrderCreated(
        uint    orderId,
        uint    createDate,
        address creator,
        uint248 amount,
        uint248 leverage,
        bool    factor,
        uint248 openRate
    );
    event OrderApproved(
        uint    orderId,
        uint    createDate,
        address creator,
        uint248 amount,
        uint248 leverage,
        bool    factor,
        uint248 openRate
    );
    event OrderClosed(
        uint    orderId,
        uint    createDate,
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
    function openOrder(uint248 leverage, bool factor) validateLeverage(leverage) validateOrderValue() payable {
        require(rate != 0);
        uint orderId = orders.length;
        uint _createDate = now;
        orders.push(Order({
            createDate : _createDate,
            creator : msg.sender,
            amount  : uint248(msg.value),
            leverage: leverage,
            factor  : factor,
            rate    : rate,
            approved: false,
            closed  : false
        }));
        OrderCreated(
            orderId,
            _createDate,
            msg.sender,
            uint248(msg.value),
            leverage,
            factor,
            rate
        );
    }

    function approveOrder(uint orderId) onlyOwner() payable {
        require(
            orders[orderId].amount != 0 &&
            !orders[orderId].closed &&
            !orders[orderId].approved &&
            uint248(msg.value) >= orders[orderId].amount
        );
        orders[orderId].approved = true;
        OrderApproved(
            orderId, 
            orders[orderId].createDate,
            orders[orderId].creator,
            orders[orderId].amount,
            orders[orderId].leverage,
            orders[orderId].factor,
            orders[orderId].rate
        );
    }

    function closeOrder(uint orderId) {
        require(msg.sender == owner || msg.sender == orders[orderId].creator);
        require(!orders[orderId].closed);
        int256 resultAmount = orders[orderId].approved ? calculateAmount(orders[orderId]) : int256(orders[orderId].amount);
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
                if(orders[i].approved){
                    int256 resultAmount = calculateAmount(orders[i]);
                    if(!(resultAmount > 0)){
                        processOrderClosing(i, resultAmount, 'contract');
                    }
                } else {
                    if(now >= orders[i].createDate + 10 minutes){
                        processOrderClosing(i, orders[i].amount, 'contract');
                    }
                }
            }
        }

        updateRate();
    }

    function processOrderClosing(uint orderId, int256 resultAmount, string initiator) internal {
        uint sendingAmount = resultAmount > 0 ? uint(resultAmount) : 0;
        if(sendingAmount > 0){
            uint maxAmount = orders[orderId].amount * 2;
            if(sendingAmount > maxAmount){
                sendingAmount = maxAmount;
            }
            //sendingAmount -= tx.gasprice * 21000;
            //if(sendingAmount < 0){
            //    sendingAmount = 0;
            //}
            //if(sendingAmount > 0){
            //    orders[orderId].creator.transfer(sendingAmount); 
            //}
        }
        orders[orderId].closed = true;
        OrderClosed(
            orderId,
            orders[orderId].createDate,
            orders[orderId].creator,
            uint248(orders[orderId].amount),
            uint248(sendingAmount),
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
}
