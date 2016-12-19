    //copyright icowarrant.com 2016
    pragma solidity ^0.4.2;
    contract tokenRecipient { function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData); }

    contract BlockRacingShares{
        /* Public variables of the token */
        string public standard = ' IcoWarrant 0.1';
        string public name_token='BlockRacingShares';//the name of token
        string public symbol_token='BRS';//the symbol of token
            string public symbol_warrant="BRW";//the symbol of warrant	
            struct balanceStruct{
                    uint256[] balance;//balance of each divident round
                    uint16 latestRound;//the latest round of this account of withdrawing divident
            }
        uint8 public decimals=18;// for display use	
        uint256 public totalSupply_warrant=1320828.357 ether;//cumulation of warrants bought
            uint256 public totalSupply_token;//cumulation of token bought
            uint256 public totalCoinsCollected;//cumulaiton of ether paid for warrant and token
            //uint256 public maxWarrantSupply=100000000 ether;//set a cap of warrants(so that tokens),default is a unreachable target	
            uint64 public timeStart_buyToken;//the start time for token purchase
            uint64 public timeEnd_buyToken;	//the end time for token purchase	
            uint64 public timeResumeTokenTransfer;//the time to resume token transfer after divident
            uint64 public timePauseTokenTransfer;//the time to start pause of token transfer triggered by divident sharing
            address public manager=0xb456dee6ea863542b877f3c9f1d683b7d11b444a;//the manager address of this contract, has rights to set params	
            bool public warrantStop;//if true, warrant transfer will be stopped for ever
            bool paramsFixed=false;//if params are fixed, they can never be changed.Warrant purchase can only start after params are fixed
            bool tokenReleaseFixed=false;//if token release time is fixed.
        mapping (address => balanceStruct) public balance_token;//the token balance map for all addresses
            mapping (address => uint256) public balance_warrant;//the warrant balance map for all addresses
            uint256 public balance_ether_issuer;//the ether balance of issuer.i.e totalcoinscollected-fee-amount withdrawn	
            enum withdrawType{
                    issuer,
                    company,
                    tokenHolder,
                    fee
            }
        mapping (address => mapping (address => uint256)) public allowance_token;//the authorization of token transfer amount to each address


            // params for dividents	
            uint64 public dividentInterval=30 days;
            uint256 public dividentsUnshared;//dividents cumulated in contract	
            uint64 public timeSpan_dividentPauseTokenTransfer=2 hours;	
            uint64 public timeSpan_dividentResumeTokenTransfer=2 hours;	
            uint64 public time_prevousDivident;//the time of previous divident sharing
            uint256[] dividentPerToken=new uint256[](1);	//the dividents per token in each divident sharing rounds
            bool paramsSet2=false;//flag for divident params

            event ShareDividents(uint16 indexed round,uint256 dividentPerToken,uint64 timePauseTransfer,uint64 timeResumeTransfer);
            event RevenueReceived(address indexed from,uint256 value,string memo);    
            event TokenSold(address buyer,uint256 value);//triggered when somebody buys token
            event TransferWarrant(address indexed from, address indexed to, uint256 value);
            event TransferToken(address indexed from, address indexed to, uint256 value);
            event Withdraw(address indexed from, address indexed to, uint8 _type, uint256 value);	
            event StartTokenPurchase(uint64 timeStart,uint64 timeEnd);
            event StopWarrant();
            event ParamsFixedEvent();
            //Initialization
            function BlockRacingShares() {    
                //manager=msg.sender;     
                balance_warrant[manager]=totalSupply_warrant;                                   	
                if(msg.value!=0&&!msg.sender.send(msg.value)) throw;                         // Send back any ether sent accidentally
            }

            function setDividentParams(		
                    uint64 dividentIntervalIn,
                    uint64 timeSpan_dividentPauseTokenTransferIn,
                    uint64 timeSpan_dividentResumeTokenTransferIn
            )OnlyManager ParamsUnFixed{		
                    //if(dividentIntervalIn<90 days)throw;		
                    dividentInterval=dividentIntervalIn;		
                    timeSpan_dividentPauseTokenTransfer=timeSpan_dividentPauseTokenTransferIn;
                    //if(timeSpan_dividentResumeTokenTransferIn<1 days)throw;
                    timeSpan_dividentResumeTokenTransfer=timeSpan_dividentResumeTokenTransferIn;
                    time_prevousDivident=uint64(now);
                    paramsSet2=true;
            }	
            function fixParams(){
                    if(!paramsSet2)	throw;
                    paramsFixed=true;
                    ParamsFixedEvent();
            }	
            function buyToken()payable{		
                    if(!tokenReleaseFixed||now<timeStart_buyToken||now>timeEnd_buyToken||msg.value==0||balance_warrant[msg.sender]==0)throw;
                    uint256 tokensToBuy=msg.value;
                    uint256 change=0;
                    if(tokensToBuy>balance_warrant[msg.sender]){
                            tokensToBuy=balance_warrant[msg.sender];
                            change=msg.value-tokensToBuy;  
                    }
                    balance_warrant[msg.sender]-=tokensToBuy;
                    totalSupply_warrant-=tokensToBuy;
                    if(balance_token[msg.sender].balance.length==0){
                            uint256[] memory balance=new uint256[](1);                        
                            balance[0]=0;
                            balance_token[msg.sender]=balanceStruct(balance,0);
                    }
                    balance_token[msg.sender].balance[0] +=tokensToBuy;	
                    totalSupply_token+=tokensToBuy;
                    totalCoinsCollected+=tokensToBuy;
                    balance_ether_issuer+=tokensToBuy;		
                    if (change>0&&!msg.sender.send(change))throw;//send back the money exeeds the warrant amount,if fail ,we have to fail the whole process		
                    TokenSold(msg.sender, tokensToBuy); 
            }	
            /*set token purchase time zone,this can be reset for any times and trigger when fixTokenRelease is called.
            don't be afraid of mistakes because there's a rule of starting 1 days later ,and mimimum 7 days*/

            function startTokenRelease (uint64 startTime,uint64 endTime) OnlyManager{
                    if(tokenReleaseFixed)throw;
                    if(startTime<=now+1 days||endTime<=startTime+7 days)	throw;
                    timeStart_buyToken=startTime;
                    timeEnd_buyToken=endTime;		
            }
            function fixTokenRelease(){
                    if(now>timeEnd_buyToken) throw;
                    tokenReleaseFixed=true;
                    StartTokenPurchase(timeStart_buyToken,timeEnd_buyToken);
            }
            /* stop the transfer of warrants i.e. disable warrants after the token purchase is over
        we set this function because we don't involve alarm clock in the contract'*/
            function stopWarrant() OnlyManager {		
                    if(timeEnd_buyToken!=0&&now>timeEnd_buyToken&&!warrantStop){
                            warrantStop=true;			
                            StopWarrant();
                    }
            }
        /* Send tokens */
        function transferToken(address _to, uint256 _value) {
                    _transferToken(msg.sender, _to,  _value);		
        }

        function _transferToken(address _from,address _to, uint256 _value)private{
                    if(now>=timePauseTokenTransfer&&now<=timeResumeTokenTransfer)	throw;		//check for pause for share divident
                    uint256 withdrawAmount=0;
                    uint256 balanceTotal=0;
		uint16 latestRound=now>=timePauseTokenTransfer?uint16(dividentPerToken.length-1):uint16(dividentPerToken.length-2);	
                uint256 roundDividentPerToken;
                uint16 j;
		balanceStruct balanceFrom=balance_token[_from];
		balanceStruct balanceTo=balance_token[_to];
		if(balanceFrom.balance.length==0)throw;//no record from sender
		if(balanceTo.balance.length==0){
			uint256[] memory balance;//=new uint256[](1);    
			balance_token[_to]=balanceStruct(balance,latestRound);
		}
		//move all the tokens in previous rounds to latest round, add up dividents
		if(balanceFrom.balance.length<latestRound+1)
			balanceFrom.balance.length=latestRound+1;		
		if(balanceTo.balance.length<latestRound+1)
			balanceTo.balance.length=latestRound+1;
		for (uint16 i=balanceFrom.latestRound;i<latestRound;i++){			
			if(balanceFrom.balance[i]>0){
                            roundDividentPerToken=0;
                                for(j=i;j<dividentPerToken.length-1;j++)
                                    roundDividentPerToken+=dividentPerToken[j];  
				withdrawAmount+=balanceFrom.balance[i]*roundDividentPerToken/(1 ether);
				balanceTotal+=balanceFrom.balance[i];
				delete balanceFrom.balance[i];
			}
		}
		balanceTotal+=balanceFrom.balance[latestRound];
        if (balanceTotal < _value) throw;           // Check if the sender has enough
        if (balanceTotal + _value <= balanceTotal) throw; // Check for overflows	
	if(balanceFrom.latestRound<latestRound)
			balanceFrom.latestRound=latestRound;

        balanceFrom.balance[latestRound] =balanceTotal- _value;                     // Subtract from the sender
        balanceTo.balance[latestRound] += _value;                            // Add the same to the recipient
		if(withdrawAmount>0&&!_from.send(withdrawAmount))	throw;					//send out divident,if fails ,fallback all
		TransferToken(_from, _to, _value);                   // Notify anyone listening that this transfer took place
    }
	function transferWarrrant(address _to, uint256 _value) {
		if(warrantStop)throw;//if warrant is stoped ,no transfer			
        if (balance_warrant[msg.sender] < _value) throw;           // Check if the sender has enough
        if (balance_warrant[_to] + _value < balance_warrant[_to]) throw; // Check for overflows
        balance_warrant[msg.sender] -= _value;                     // Subtract from the sender
        balance_warrant[_to] += _value;                            // Add the same to the recipient
        TransferWarrant(msg.sender, _to, _value);                   // Notify anyone listening that this transfer took place
    }	
	//withdraw issuance income
	function withdrawIssueIncome (address _to,uint256 _value) OnlyManager{		
		if(_value<=balance_ether_issuer){
			balance_ether_issuer-=_value;
			if(!_to.send(_value))throw;
			Withdraw(msg.sender, _to, 0,_value);
		}
		else throw;
	}
	//collect revenue for divident
	function collectRevenue(string memo)payable{
		if(msg.value==0) throw;
		dividentsUnshared+=msg.value;
		RevenueReceived(msg.sender,msg.value,memo);
	}
	//this function can be triggered by anyone
	function shareDividents(){		
		if(now< dividentInterval+time_prevousDivident||dividentsUnshared< totalSupply_token/10)throw;
		time_prevousDivident=uint64(now);		
		dividentPerToken[dividentPerToken.length-1]=dividentsUnshared*(1 ether)/totalSupply_token;				
		dividentPerToken.length+=1;//dividentPerToken.length+1;		
		dividentsUnshared=0;
		timePauseTokenTransfer=uint64(now)+timeSpan_dividentPauseTokenTransfer;
		timeResumeTokenTransfer=timePauseTokenTransfer+timeSpan_dividentResumeTokenTransfer;		
		ShareDividents(uint16(dividentPerToken.length-1),dividentPerToken[dividentPerToken.length-2],timePauseTokenTransfer,timeResumeTokenTransfer);
               
	}
	function withdrawDivident(address _to){
		if(now<timePauseTokenTransfer)throw;//pause withdrawdivident when new divident is announced. to protect buyer from price-misunderstanding			
		if(_to==0)
			_to=msg.sender;
		uint256 withdrawAmount=0;	
                uint256 balanceTotal=0;	
                uint256 roundDividentPerToken;                
		//balanceStruct b=balance_token[msg.sender];
		if(balance_token[msg.sender].balance.length==0)throw;	
                balance_token[msg.sender].balance.length=dividentPerToken.length;	
		for (uint16 i=balance_token[msg.sender].latestRound;i<dividentPerToken.length-1;i++){	                        
                        if(balance_token[msg.sender].balance[i]>0){
                            roundDividentPerToken=0;
                            for(uint16 j=i;j<dividentPerToken.length-1;j++)
                                roundDividentPerToken+=dividentPerToken[j];                            
                            withdrawAmount+=balance_token[msg.sender].balance[i]*roundDividentPerToken/(1 ether);
                            balanceTotal+=balance_token[msg.sender].balance[i];
                            delete balance_token[msg.sender].balance[i];
                        }
		}
                balance_token[msg.sender].latestRound=uint16(dividentPerToken.length-1);
                balance_token[msg.sender].balance[dividentPerToken.length-1] =balanceTotal;
		if(withdrawAmount>0){			
                        if(!_to.send(withdrawAmount))throw;			
			Withdraw(msg.sender, _to, 2,withdrawAmount);
		}
	}
	
    /* Allow another contract to spend some tokens in your behalf */
     function approve(address _spender, uint256 _value)
        returns (bool success) {
        allowance_token[msg.sender][_spender] = _value;
        return true;
    }
    /* Approve and then comunicate the approved contract in a single tx */
     function approveAndCall(address _spender, uint256 _value, bytes _extraData)
        returns (bool success) {
        tokenRecipient spender = tokenRecipient(_spender);
        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, this, _extraData);
            return true;
        }
    }
	/* A contract attempts to get the coins */
    function tokenTransferFrom(address _from, address _to, uint256 _value) returns (bool success) {     
        if (_value > allowance_token[_from][msg.sender]) throw;   // Check allowance     
		_transferToken(_from, _to,  _value);		
        allowance_token[_from][msg.sender] -= _value;       
        return true;
    }
	modifier OnlyManager(){
		if(msg.sender==manager){
			_;
		}else throw;
	}
	modifier ParamsUnFixed(){
		if(!paramsFixed){
			_;
		}else throw;
	}
	modifier ParamsFixed(){
		if(paramsFixed){
			_;
		}else throw;
	}
    function () {
        	throw;     // Prevents accidental sending of ether
    }
    function getWarrantBalance(address addr) returns(uint) {
		return balance_warrant[addr];
	}
    function getTokenBalance(address addr) returns(uint) {
        uint256 balanceTotal;
        balanceStruct balanceFrom=balance_token[addr];
        if(balanceFrom.balance.length==0)
            return 0;
        uint latestRound=dividentPerToken.length;	
        if (latestRound>balanceFrom.balance.length)
            latestRound=balanceFrom.balance.length;
        for (uint i=balanceFrom.latestRound;i<latestRound;i++){						
		balanceTotal+=balanceFrom.balance[i];							
        }		
		return balanceTotal;
    }
    function getDividentBalance(address addr) returns(uint) {
        uint256 withdrawAmount;	
        uint256 roundDividentPerToken;	
        uint16 latestRound=now>=timePauseTokenTransfer?uint16(dividentPerToken.length-1):uint16(dividentPerToken.length-2);	
		balanceStruct b=balance_token[addr];
		for (uint16 i=b.latestRound;i<latestRound&&i<b.balance.length;i++){	
                    if(b.balance[i]>0){	
                        roundDividentPerToken=0;
                        for(uint16 j=i;j<latestRound;j++)
                                    roundDividentPerToken+=dividentPerToken[j];  	                                        
			withdrawAmount+=b.balance[i]*roundDividentPerToken/(1 ether);
                    }        
		}
        return  withdrawAmount;
    }
    
}


