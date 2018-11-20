pragma solidity 0.4.24;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../../contracts/PartitionInstantiator.sol";

contract TestSlice is PartitionInstantiator{
  uint nextIndex = 0;
    
  bytes32[] replyArray = new bytes32[](15);
  uint256[] postedTimes = new uint[](15);
  
  address mockAddress1 = 0x0014060Ff383C9B21C6840A3b14AAb06741E5c49;

 function testSlice() public {
    uint firstIndex = instantiate(msg.sender,mockAddress1,"initialHash","finalHash", 50000, 15, 55);   
    uint secondIndex = instantiate(msg.sender,mockAddress1,"initialHash","finalHash", 50000, 15, 55);   
    uint thirdIndex = instantiate(msg.sender,mockAddress1,"initialHash","finalHash", 50000, 15, 55);   

  //if intervalLength < 2 * queryLastIndex
    uint leftPoint = 2;
    uint rightPoint = 5;
   
    slice(firstIndex,leftPoint, rightPoint);

    for(uint i = 0; i < instance[firstIndex].querySize - 0; i++){
      if(leftPoint + i < rightPoint){
        Assert.equal(instance[firstIndex].queryArray[i], leftPoint + i,"Queryarray[i] must be = leftPoint +i");
      }else{
        Assert.equal(instance[firstIndex].queryArray[i], rightPoint, "queryArray[i] must be equal rightPoint"); 
      }
    }

    leftPoint = 50;
    rightPoint = 55;
 
    slice(secondIndex,leftPoint, rightPoint);

    for(i = 0; i < instance[secondIndex].querySize - 1; i++){
      if(leftPoint + i < rightPoint){
        Assert.equal(instance[secondIndex].queryArray[i], leftPoint + i,"Queryarray[i] must be = leftPoint +i");
      }else{
        Assert.equal(instance[secondIndex].queryArray[i], rightPoint, "queryArray[i] must be equal rightPoint"); 
      }
    }
    leftPoint = 0;
    rightPoint = 1;
 
    slice(secondIndex,leftPoint, rightPoint);

    for(i = 0; i < instance[secondIndex].querySize - 1; i++){
      if(leftPoint + i < rightPoint){
        Assert.equal(instance[secondIndex].queryArray[i], leftPoint + i,"Queryarray[i] must be = leftPoint +i");
      }else{
        Assert.equal(instance[secondIndex].queryArray[i], rightPoint, "queryArray[i] must be equal rightPoint"); 
      }
    }
    //else path
    leftPoint = 1;
    rightPoint = 600;
   
    slice(thirdIndex,leftPoint, rightPoint);

    uint divisionLength = (rightPoint - leftPoint) / (instance[1].querySize - 1);
    for (i = 0; i < instance[thirdIndex].querySize - 1; i++) {
      Assert.equal(instance[thirdIndex].queryArray[i], leftPoint + i * divisionLength, "slice else path");
    }
    leftPoint = 150;
    rightPoint = 600;
   
    slice(thirdIndex,leftPoint, rightPoint);

    divisionLength = (rightPoint - leftPoint) / (instance[thirdIndex].querySize - 1);
    for (i = 0; i < instance[thirdIndex].querySize - 1; i++) {
      Assert.equal(instance[thirdIndex].queryArray[i], leftPoint + i * divisionLength, "slice else path");
    }
  }
}

