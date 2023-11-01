//SPDX-License-Identifier: Unlicense
pragma solidity >=0.7.0 <0.9.0;

contract Migrations {
    address public owner;
    uint public last_completed_migration; //各移行を追跡する


    constructor() {
        owner = msg.sender; // Migrationのdeployerをownerにする
    }

    modifier restricted() { // Migrationのdeployer onlyにするmoddifier
        if(msg.sender == owner) _;
    }

    function setCompleted(uint completed) public restricted { //移行が完了したら入力
        last_completed_migration = completed;
    }

    function upgrade(address new_address) public restricted { //new_addressへ更新する
        Migrations upgraded = Migrations(new_address); //インスタンスupgraded作成、新しいaddressへ移行
        upgraded.setCompleted(last_completed_migration); //移行したら上の関数に入力
    }
}