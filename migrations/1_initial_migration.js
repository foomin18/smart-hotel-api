// eslint-disable-next-line no-undef
const Migrations = artifacts.require('Migrations');

module.exports = function(deployer) { //deploy the migration contract
    deployer.deploy(Migrations);  //transactionを更新することでスマートコントラクトを更新する
};