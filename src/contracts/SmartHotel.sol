//SPDX-License-Identifier: Unlicense
pragma solidity >=0.7.0 <0.9.0;

import "../../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../node_modules/@openzeppelin/contracts/utils/math/Math.sol";

import './HotelToken.sol';
import './TimeManager.sol';

contract SmartHotel {
    string public name = 'SmartHotel';
    // 1 token = 1 day 
    HotelToken public hotelToken;
    //time manager
    TimeManager private timeManager;
    address payable public owner;  //payable
    // price of one token in ETH
    uint16 public roomNum;
    uint64 public hotelTokenPrice;
    uint256 deployTime;
    

    struct RoomPass {
        uint256 password;
        bool set;
    }

    struct Appointment {  
        bool isAppointment;
        string partyName;
        address userAddress;
    }

    struct UserBooking {
        uint256 timestamp;
        uint8 numDays;
        bool isCheckedIn;
        uint16 roomId;
    }

    mapping(uint16 => RoomPass) private roomPasses;  //roomid => roompass
    mapping(uint16 => bool) public roomKeyStates;  //is room key opening
    //unix time for days; key must be mod 86400
    mapping(uint16 => mapping(uint256 => Appointment)) scheduleByTimestamp;  //部屋分けはネストで表現roomiduint=>timestampuint=>appo
    // set array length
    mapping(address => UserBooking[]) public userBookings;

    event TokenPriceChanged(uint64 oldPrice, uint64 newPrice);
    event TokenBought(address indexed from, uint256 sum, uint64 price);
    event AppoScheduled(address indexed from, uint256 timestamp, uint256 span, uint16 room);
    event AppoRefunded(address indexed from, uint256 timestamp, uint256 span, uint8 index);
    event CheckedIn(address indexed user, uint256 timestamp);
    event CheckedOut(address indexed user, uint256 timestamp);
    event roomPassOK(address indexed user, uint256 timestamp);
    event keyOpened(address indexed user, uint256 timestamp);
    event keyLocked(address indexed user, uint256 timestamp);

    modifier onlyOwner() {
        require(msg.sender == owner, "owner restricted funtionality");
        _;
    }

    modifier validMonth(uint8 _m) {
        require(_m > 0 && _m < 13, "Month must be 1 - 12 value");
        _;
    }

    modifier validDay(uint8 _d) {
        require(_d > 0 && _d < 32, "Invalid day");
        _;
    }

    modifier validNumDays(uint8 _num) {
        require(_num > 0, "Must be a value above 0");
        _;
    }

    modifier validTimestamp(uint256 _t) {
        validateTimestamp(_t);
        _;
    }

    modifier validRoomId(uint16 _id) {
        require(0 <= _id && _id <= roomNum, "Invalid room Id");
        _;
    }

    modifier validAppoRange(uint256 _t, uint8 _r) {
        isMod86400(_t);
        require(_r <= 365 && _r > 0, "Valid ranges are 1 - 365");
        _;
    }

    // name can't be empty
    modifier validName(string memory _s) {
        require(bytes(_s).length != 0, "Party name cannot be blank");
        _;
    }

    constructor(
        uint64 _initialPrice,
        uint16 _roomNum
    ) {
        deployTime = block.timestamp;
        hotelToken = new HotelToken(address(this));
        owner = payable(msg.sender);
        // timeManager Contract
        timeManager = new TimeManager();
        hotelTokenPrice = _initialPrice;
        roomNum = _roomNum;
    }

    //timestamp cannot be before deployTime && must be mod 86400
    //because we use unix days as our mapping keys
    function validateTimestamp(uint256 _t) private view {
        require(
            _t > deployTime,
            "Cannot use before deploy timestamp"
        );
        isMod86400(_t);
    }

    function isMod86400(uint256 _t) private pure {
        require(
            _t % 86400 == 0,
            "Timestamp must be mod 86400; try using getUnixTimestamp for a given month, day, year"
        );
    }

    //get a unix timestamp given month, day, year.
    //Can be calculated on the front-end
    //returns mod86400 uint256
    function getUnixTimestamp(
        uint16 _year,
        uint8 _month,
        uint8 _day
    ) public view returns (uint256) {
        return timeManager.toTimestamp(_year, _month, _day);
    }

    //return balanceOf a given address from our token contract
    function getTokenBalance(address _addr) public view returns (uint256) {
        return hotelToken.balanceOf(_addr);
    }

    //return all bookings for a given address
    //userBookings is a dynamic array, so this function is meant to be read-only and should not be used in any state-altering functionality
    function getAppoByUser(address _addr)
        public
        view
        returns (UserBooking[] memory)
    {
        return userBookings[_addr];  //UserBooking型配列が返る
    }

    //Returns an array of events for a given range
    //roomnum追加
    function getAppoList(uint16 _roomId, uint256 _start, uint8 _numDays) 
        public
        view
        validRoomId(_roomId)
        validAppoRange(_start, _numDays)
        returns (address[] memory)
    {
        uint8 i = 0;
        // up to 31 days in a month
        address[] memory monthlyAppointments = new address[](_numDays);
        for (i; i < _numDays; i++) {
            Appointment memory foundAppointment = scheduleByTimestamp[_roomId][
                _start + (i * 86400)
            ];
            if (foundAppointment.isAppointment) {
                monthlyAppointments[i] = foundAppointment.userAddress;
            }
        }
        // returns an array with the correct number of days
        return monthlyAppointments;
    }

    //timestamp must be mod 86400 and _numDays must match total tickets
    function bookAppo(
        uint16 _roomId,
        string memory _name,
        uint256 _timestamp,
        uint8 _numDays
    )
        public
        validRoomId(_roomId)
        validName(_name)
        validTimestamp(_timestamp)
        validNumDays(_numDays)
    {
        hotelToken.burnToken(msg.sender, _numDays);

        for (uint8 i = 0; i < _numDays; i++) {
            // Solidity reverts state changes when require is violated
            // this allows us to loop through and create the necessary stateChanges in 1 for loop
            require(
                scheduleByTimestamp[_roomId][_timestamp + (86400 * i)].isAppointment !=
                    true,
                "Appointment already exists on one or more of the requested dates"
            );
            // save each booking day indexed by timestamp; this makes it easy to look up a range of days by unix uint256 mod 86400
            scheduleByTimestamp[_roomId][_timestamp + (86400 * i)] = Appointment(
                true,
                _name,
                msg.sender
            );
        }
        // save all user timestamps in array - we can use the timestamp + numDays as keys to our primary Appointment mapping
        userBookings[msg.sender].push(UserBooking(_timestamp, _numDays, false, _roomId));

        emit AppoScheduled(msg.sender, _timestamp, _numDays, _roomId);
    }

    function removeUserBooking(uint8 _indexToDelete) internal {
        require(_indexToDelete < userBookings[msg.sender].length);
        userBookings[msg.sender][_indexToDelete] = userBookings[msg.sender][
            userBookings[msg.sender].length - 1
        ];
        userBookings[msg.sender].pop();
    }

    //for a production app you should cap maxRedemptions for users to avoid cancellation abuse
    function refundAppo(uint8 _index) public {
        // first get the timestamp and numdays from timestamp from the index
        //require(userBookings[msg.sender][_index].isCheckedIn != true, "You cannot refund appo that checked in");
        uint256 timestamp = userBookings[msg.sender][_index].timestamp;
        uint8 numDays = userBookings[msg.sender][_index].numDays;
        uint16 roomId = userBookings[msg.sender][_index].roomId;
        require(timestamp > 0 && numDays > 0, "no booking found at that index");
        validateTimestamp(timestamp);
        // cannot cancel past events
        require(
            timestamp > block.timestamp,
            "cannot cancel events in the past"
        );
        
        for (uint8 i = 0; i < numDays; i++) {
            uint256 currDay = timestamp + (86400 * i);
            // Solidity reverts state changes when require is violated
            // this allows us to loop through and create the necessary stateChanges in 1 for loop
            require(
                scheduleByTimestamp[roomId][currDay].isAppointment == true,
                "Appointment does not exist"
            );
            require(
                scheduleByTimestamp[roomId][currDay].userAddress == msg.sender,
                "Cannot refund an appointment msg.sender did not create"
            );
            // this effectively deletes the event
            scheduleByTimestamp[roomId][currDay].isAppointment = false;
        }
        //予約の削除
        removeUserBooking(_index);
        //トークンの返済
        hotelToken.mintToken(msg.sender, numDays);
        //UIに反映するためのイベントのemit
        emit AppoRefunded(msg.sender, timestamp, numDays, _index);
    }

    //1トークンごとのETHを指定する
    function changeTokenPrice(uint64 _newPrice) public onlyOwner {
        require(_newPrice > 0, "New price must be more than zero");
        // emit an event w/ new and old values
        emit TokenPriceChanged(hotelTokenPrice, _newPrice);
        //check if msg.sender have minter role
        hotelTokenPrice = _newPrice;
    }

    function buyTokens(uint64 _numTokens) public payable {
        require(msg.value > 0, "must send ether in request");
        require(msg.value >= (hotelTokenPrice * _numTokens), "not enough ether sent in request");
        // transfers ETH to owner account
        (bool sent, ) = owner.call{value: hotelTokenPrice * _numTokens}("");  //call function
        require(sent, "Failed to send Ether");

        uint64 excessEth = uint64(msg.value - (hotelTokenPrice * _numTokens));
    
        if (excessEth > 0) {
            payable(msg.sender).transfer(excessEth);
        }
        
        hotelToken.mintToken(msg.sender, _numTokens);
        // use hotelTokenPrice for easy human-readable USD value
        emit TokenBought(msg.sender, _numTokens, hotelTokenPrice);
    }

    function checkIn(uint256 _timestamp, uint8 _index) public validTimestamp(_timestamp) { //チェックインする日にち予約番号
        uint16 roomId = userBookings[msg.sender][_index].roomId;
        Appointment memory appointment = scheduleByTimestamp[roomId][_timestamp];
        //実際にはblock.timestampをmod86400できりおとし、それと_timestampが一致するか同課のrequireを追加する
        //require(_timestamp == timeManager.marume86400(block.timestamp), "This is not today");  ///test
        require(appointment.isAppointment, "No appointment exists at this timestamp");
        require(appointment.userAddress == msg.sender, "You do not own this appointment");
        require(userBookings[msg.sender][_index].isCheckedIn != true, "You have already checked in");

        //チェックイン
        userBookings[msg.sender][_index].isCheckedIn = true;

        emit CheckedIn(msg.sender, block.timestamp);
    }

    function checkOut(uint256 _timestamp, uint8 _index) public validTimestamp(_timestamp) {
        uint16 roomId = userBookings[msg.sender][_index].roomId;
        Appointment memory appointment = scheduleByTimestamp[roomId][_timestamp];
        require(appointment.isAppointment, "No appointment exists at this timestamp");
        require(appointment.userAddress == msg.sender, "You do not own this appointment");
        require(userBookings[msg.sender][_index].isCheckedIn == true, "You have not checked in");

        //チェックアウト
        roomPasses[roomId].set = false;
        userBookings[msg.sender][_index].isCheckedIn = false;
        removeUserBooking(_index);  //予約を削除
        emit CheckedOut(msg.sender, block.timestamp);
    }

    //チェックインして部屋に入る前に実行する関数
    function roomPassSet(uint8[6] memory _input, uint256 _timestamp, uint8 _index) public validTimestamp(_timestamp) {
        uint16 roomId = userBookings[msg.sender][_index].roomId;
        Appointment memory appointment = scheduleByTimestamp[roomId][_timestamp];
        require(appointment.isAppointment, "No appointment exists at this timestamp");
        require(appointment.userAddress == msg.sender, "You do not own this appointment");
        require(userBookings[appointment.userAddress][_index].isCheckedIn, "User must be checked in to generate a one-time code");

        for (uint8 i = 0; i < 6; i++) {
            require(0 <= _input[i] && _input[i] < 10, "password must be 6keta");
        }

        roomPasses[roomId].password = uint256(keccak256(abi.encodePacked(_input)));//

        roomPasses[roomId].set = true;  //issue
        // Emit an event with the one-time code
        emit roomPassOK(appointment.userAddress, block.timestamp);
    }

    //開錠関数
    function keyOpen(uint8[6] memory _input, uint256 _timestamp, uint8 _index) public validTimestamp(_timestamp) {
        uint16 roomId = userBookings[msg.sender][_index].roomId;
        Appointment memory appointment = scheduleByTimestamp[roomId][_timestamp];
        require(appointment.isAppointment, "No appointment exists at this timestamp");
        require(appointment.userAddress == msg.sender, "You do not own this appointment");
        require(userBookings[appointment.userAddress][_index].isCheckedIn, "User must be checked in to open key");
        require(roomKeyStates[roomId] == false, "This room is already opened");
        require(roomPasses[roomId].set == true, "Please set your password");
        require(roomPasses[roomId].password == uint256(keccak256(abi.encodePacked(_input))), "Password is incorrect");

        roomKeyStates[roomId] = true;

        emit keyOpened(appointment.userAddress, block.timestamp);  //roomnum
    }

    function keyLock(uint256 _timestamp, uint8 _index) public validTimestamp(_timestamp) {
        uint16 roomId = userBookings[msg.sender][_index].roomId;
        Appointment memory appointment = scheduleByTimestamp[roomId][_timestamp];
        require(appointment.isAppointment, "No appointment exists at this timestamp");
        require(appointment.userAddress == msg.sender, "You do not own this appointment");
        require(userBookings[appointment.userAddress][_index].isCheckedIn, "User must be checked in to lock the key");
        require(roomKeyStates[roomId] == true, "This room is already closed");
        //require(roomPass.used == true, "Room key must be used before locking");

        // Lock the room key
        roomKeyStates[roomId] = false;

        // Emit an event to indicate that the key is locked
        emit keyLocked(appointment.userAddress, block.timestamp);
    }

    //以下テスト用関数
    function showAppo(uint16 _roomId, uint256 _timestamp) public view validTimestamp(_timestamp) returns (Appointment memory appo) {
        appo = scheduleByTimestamp[_roomId][_timestamp];
    }

    function isCheckedIn(uint8 _index) public view returns (UserBooking memory booking) {
        booking = userBookings[msg.sender][_index];
    }

    function isDoorOpen(uint16 _roomId) public view returns (bool) {
        return roomKeyStates[_roomId];
    }
}

