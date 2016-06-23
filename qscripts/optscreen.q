\c 45 160
\p 7799 
/////Load all data from csv files
allsym:("SS";enlist ",")0:`:../data/stocks.csv;
globaltbl:("DSFFFFFS";enlist ",")0:`:../data/glbtbl.csv;
bhav:("SSDFSFFFFFJFIID";enlist ",")0:`:../data/latestbhav.csv;
otmtbl:select from bhav where INSTRUMENT=`OPTSTK, OPTION_TYP=`PE;
`SYMBOL xkey `otmtbl;
mktlots:("SSIII";enlist ",")0:`:../data/fo_mktlots.csv;
mktlots:`UNDERL`SYMBOL`FIRST`SECOND`THIRD xcol mktlots;
mktlots:select SYMBOL,SECOND from mktlots;
`SYMBOL xkey `mktlots;
vola:("DSFFFFFFFFFFFFFF";enlist ",")0:`:../data/volatility.csv;
vola:`Date`SYMBOL`Close`PrevClose`PnL`PrevDayVolty`DayVolty`AnnualVolty`FutClose`FutPrevClose`FutPnL`PrevFutPnL`DayFutVolty`AnnualFutVolty`DailyVolty`AnnualVolty xcol vola;
vola:select SYMBOL, Close, AnnualVolty from vola;
`SYMBOL xkey `vola;

adjDate:{[dt] 0 -1 0i+`year`mm`dd$dt};     / 2015.01.01 -> 2015 0 1i

getHist:{[ticker; sdt; edt]
	tmpl:"http://ichart.finance.yahoo.com/table.csv?s=%tick&d=%em&e=%ed&f=%ey&a=%sm&b=%sd&c=%sy&g=d&ignore=.csv";
	args:string ticker,raze adjDate each (sdt;edt);
	url:ssr/[tmpl; ("%tick";"%sy";"%sm";"%sd";"%ey";"%em";"%ed"); args];
	/show url;
	raw:system "wget  -qO- ","\"",url,"\"";
	/show raw;
	t:("DFFFFJF"; enlist ",") 0:raw;
	/show t;
	t:`Date xasc `Date`Open`High`Low`Close`Volume`AdjClose  xcol t;
	:t;
	}

getData:{[ticker; sdt] select Date, AdjClose from getHist[ticker;"D"$sdt;.z.D]}

getVolty:{[ticker]
	tempt:getData[ticker; "2016.02.01"];
	tempt:select Date, AdjClose, prevAdjClose:next AdjClose from tempt;
	tempt:select from tempt where not prevAdjClose = 0n;
	tempt:select Date, lnret:100*log(AdjClose % prevAdjClose) from tempt;
	volt[0]:select med lnret from tempt;
	vold[1]:select dev lnret from tempt;
	:volt;
	}

getDataR:{[ticker; sdt] select Date, Close, AdjClose from getHist[ticker;.z.D-"I"$sdt;.z.D]}
getTrend:{[ticker]
	temp:getDataR[ticker;"150"];
	temp:select Date, Symbol:ticker, Close, AdjClose, smvg:20 mavg Close, lmvg:50 mavg Close from temp;
	temp:select Date, Symbol, Close, AdjClose, smvg, lmvg, rtio:smvg % lmvg, trend:`D from temp;
	temp:update trend:`U from temp where rtio > 1.0, rtio > prev rtio;
	temp:update trend:`C from temp where rtio > 1.045, trend=`D;
	retval:-1#temp;
	globaltbl::globaltbl,retval;
	:exec trend from retval;
	}
//
pi:acos -1
nx:{abs(x>0)-(exp[-.5*x*x]%sqrt 2*pi)*t*.31938153+t*-.356563782+t*1.781477937+t*-1.821255978+1.330274429*t:1%1+.2316419*abs x}
bsfast: {[x;s;v;t;r;opt]    
    d1:(log[s%x]+(r+((v*v)*0.5))*t)%(v*sqrt t);
    d2:d1 - (v * sqrt t);
    :$[opt;(-1*s*nx[-1*d1])+(x*(exp(-1*r*t)))*nx[-1*d2];((s*nx[d1])+(-1*x*(exp(-1*r*t)))*nx[d2]) ]
    }

getIV: {[x;s;p;v;t;r;opt]
    ip:0f;
    ip:bsfast[x;s;v;t;r;opt];
    al:v-0.2;
    ah:v+0.2;
    countr:10;
    while[countr-:1 ;  $[(ip < p ); [al:v];[ah:v] ]; 
        v:0.5 * (al+ah);
        ip:bsfast[x;s;v;t;r;opt];
         ];
     :v
    }

getDelta: {[x;s;v;t;r;opt]    
    d1:(log[s%x]+(r+((v*v)*0.5))*t)%(v*sqrt t);
    :nx[-1*d1];
    }
//
result:select symbol, trend: raze (getTrend each symbol) from allsym;
globaltbl:select Date, SYMBOL:{a:"." vs x; "S"$a[0]} each string Symbol, Close, AdjClose, Ratio:rtio, Trend:trend  from globaltbl;
`SYMBOL xkey `globaltbl;
trythese: select  SYMBOL, EXPIRY_DT, STRIKE_PR, OPEN, HIGH, LOW, CLOSE, Days:(EXPIRY_DT - TIMESTAMP), TIMESTAMP,Close, AdjClose from (otmtbl lj globaltbl)  where Trend in `C`U, STRIKE_PR < AdjClose;
//
finalone:trythese lj vola;
finalone:select SYMBOL,EXPIRY_DT, STRIKE_PR, Close,OPEN, CLOSE, AnnualVolty, Days,IV:getIV'[STRIKE_PR;Close;CLOSE;AnnualVolty;Days%365;.09;1],TIMESTAMP from finalone where OPEN > 0.0;
finalone:select SYMBOL,EXPIRY_DT, STRIKE_PR, Close,OPEN, CLOSE, AnnualVolty, Days,IV,Delta:getDelta[STRIKE_PR;Close;IV;Days%365;.09;1],TIMESTAMP from finalone;
finalone:finalone lj mktlots;
finalone:select SYMBOL,EXPIRY_DT, STRIKE_PR, Close,OPEN, CLOSE, AnnualVolty, Days,IV,Delta,ProbOTM:1-Delta,LotSize:SECOND,Notional:STRIKE_PR*SECOND, TIMESTAMP from finalone;
finalone:select SYMBOL,EXPIRY_DT, STRIKE_PR, Close,OPEN, CLOSE, AnnualVolty, Days,IV,Delta,ProbOTM,LotSize,Notional,Margin:Notional*.14,TIMESTAMP from finalone;
finalone:select SYMBOL,EXPIRY_DT, STRIKE_PR, Close,OPEN, CLOSE, AnnualVolty, Days,IV,Delta,ProbOTM,LotSize,Notional,Margin,Profit:CLOSE*LotSize,TIMESTAMP from finalone;
finalone:select SYMBOL,EXPIRY_DT, STRIKE_PR, Close,OPEN, CLOSE, AnnualVolty, Days,IV,Delta,ProbOTM,LotSize,Notional,Margin,Profit,Return:Profit%Margin,TIMESTAMP from finalone;
