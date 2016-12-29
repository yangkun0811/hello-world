VERSION[`CTAACD]:"2016.12.10";

\d .ctaacd
timedict:`TIME_DELAY`MORNING_TRADE_START`MORNING_TRADE_END`MID_TRADE_START`MID_TRADE_END`AFTNOON_TRADE_START`AFTNOON_TRADE_END`NIGHT_TRADE_START`NIGHT_TRADE_END`FORCE_COVER_START`FORCE_COVER_END!(00:00:30.000;09:15:00.000;10:15:00.000;10:15:00.000;11:30:00.000;13:00:00.000;15:15:00.000;21:00:00.000;01:00:00.000;14:55:00.000;14:59:00.000);
paramdict:`PlaceNum`stoplossfactor`NewDayStartTime`ObvStartTime`EndTradeTime`ObvWindow!(1f;5i;09:00:00;09:00:00;14:59:00;5i);
his_bar_dict:(`llbar`lbar)!((0ne;0ne;0ne;0ne);(0ne;0ne;0ne;0ne));
quote_bar_dict_ctaacd:(`openpx`closepx`highpx`lowpx)!(0ne;0ne;0ne;0ne);
\d .

// Write log according to strategy id.
write_logs_ctaacd:{[tid;x] $[(type x) = 10h;longstr:x;longstr:string x];logfilepath:`$(":/tmp/","log_",(string tid),".txt");h:hopen logfilepath;(neg h)[longstr];hclose h};

// Round price to the same digit with unit price.
round_to_unit_px_ctaacd:{[tid;fsym;price]h:Tx[tid];unitpx:pxunit[fsym];unitpx*`int$(price%unitpx)};

//yk:全天分为早，中，下午,夜盘四个时间段
// Check time slot is enable for open.     
check_time_status_open_ctaacd:{[tid]
    h:Tx[tid];
    status:$[((QX[h[`FUT];`time] within (.ctaacd.timedict`MORNING_TRADE_START;.ctaacd.timedict`MORNING_TRADE_END))|(QX[h[`FUT];`time] within (.ctaacd.timedict`MID_TRADE_START;.ctaacd.timedict`MID_TRADE_END))|(QX[h[`FUT];`time] within (.ctaacd.timedict`AFTNOON_TRADE_START;.ctaacd.timedict`AFTNOON_TRADE_END))|(QX[h[`FUT];`time] within (.ctaacd.timedict`NIGHT_TRADE_START;.ctaacd.timedict`NIGHT_TRADE_END)));1b;0b];
    status
    };

// Check time slot is enable for close.  check_time_status_close_ctaacd[tid]
check_time_status_close_ctaacd:{[tid]
    h:Tx[tid];
    status:$[((QX[h[`FUT];`time] within (.ctaacd.timedict`MORNING_TRADE_START;.ctaacd.timedict`MORNING_TRADE_END))|(QX[h[`FUT];`time] within (.ctaacd.timedict`MID_TRADE_START;.ctaacd.timedict`MID_TRADE_END))|(QX[h[`FUT];`time] within (.ctaacd.timedict`AFTNOON_TRADE_START;.ctaacd.timedict`AFTNOON_TRADE_END))|(QX[h[`FUT];`time] within (.ctaacd.timedict`NIGHT_TRADE_START;.ctaacd.timedict`NIGHT_TRADE_END)));1b;0b];
    status
    };
	
// Check time slot is enable for force cover.  check_time_status_forcecover_ctaacd[tid]
check_time_status_forcecover_ctaacd:{[tid]
    h:Tx[tid]; 
    status:$[(QX[h[`FUT];`time] within (.ctaacd.timedict`FORCE_COVER_START;.ctaacd.timedict`FORCE_COVER_END));1b;0b];
    status
    };
	
// Check whether the strategy is stopped. check_strategy_status_ctaacd[tid]
check_strategy_status_ctaacd:{[tid] 
    h:Tx[tid];
	placenum:h`PlaceNum;
	position:`float$h`POSITION;
	status:$[(0b=T[tid;`active])|(T[tid;`stop]=`d)|(T[tid;`stop]=`r);0b;1b];
	//if[not (position in (-1f*placenum;0f;placenum));status:0b;write_logs_ctaacd[tid;-3!("Time:";now[];"The Position is wrong!")];stop_strategy_ctaacd[tid];];
    if[not check_position_ctaacd[tid];status:0b;write_logs_ctaacd[tid;-3!("Time:";now[];"The Position and the POSITION Table are not match!")];stop_strategy_ctaacd[tid];];
    status
    };

// Block the invalidate price of future.
fut_price_filter_ctaacd:{[tid]
    h:Tx[tid];
    errorstatus:0;
    if[((QX[(h`FUT);`o1px]=0ne)|(QX[(h`FUT);`o1px]=0w)|(QX[(h`FUT);`o1px]=0e)|
        (QX[(h`FUT);`b1px]=0ne)|(QX[(h`FUT);`b1px]=0w)|(QX[(h`FUT);`b1px]=0e)|
        (QX[(h`FUT);`sup]=0ne) |(QX[(h`FUT);`sup]=0w) |(QX[(h`FUT);`sup]=0e) |
        (QX[(h`FUT);`inf]=0ne) |(QX[(h`FUT);`inf]=0w) |(QX[(h`FUT);`inf]=0e) |
        (null QX[h`FUT;`settledate])|(null QX[h`FUT;`multiplier]));
       errorstatus:1;
       write_logs_ctaacd[tid;-3!("Time:";now[];"Error status was found in future price filter.")];
    ];
    errorstatus
    };
    
//check position;check_position_ctaacd[tid]
check_position_ctaacd:{[tid]
    h:Tx[tid];
    position:`float$h`POSITION;
    futcode:h`FUT;
    futacc:(h`OPENACCT)[product;`stkacc];
    postable:select from P where trader=tid,account=futacc,fsym=futcode;
    totalqty:0f^first exec qty from postable;
    status:$[position=totalqty;1b;0b];
    status
    };
    

// Update quote dictionary when new quote data arrives. 
update_quote_dict_ctaacd:{[tid] 
    h:Tx[tid];
    freq:h`FREQ;
    futcode:h`FUT;
    quotedata:QX[futcode];
    quotetime:quotedata[`time];
    lastbarmm:h`LASTBARMM;
    curbarmm:(60i*"I"$((":" vs string quotetime)[0]))+"I"$((":" vs string quotetime)[1]);
    curqbar:h`CURQBAR;
    $[(curbarmm<>lastbarmm)&(0 = `int$(curbarmm-lastbarmm) mod freq);
        [
         write_logs_ctaacd[tid;-3!("Time:";quotedata[`time];"new bar time.")];
         Tx[tid;`LASTBARMM]:curbarmm;
         curqbar[`openpx]:quotedata[`price];
         curqbar[`closepx]:quotedata[`price];
         curqbar[`highpx]:quotedata[`price];
         curqbar[`lowpx]:quotedata[`price];
         update_bar_table_ctaacd[tid;quotedata[`price]];
        ];
        [
         curqbar[`closepx]:quotedata[`price];
         if[quotedata[`price]>curqbar[`highpx];curqbar[`highpx]:quotedata[`price];];
         if[quotedata[`price]<curqbar[`lowpx];curqbar[`lowpx]:quotedata[`price];];
        ]
    ];
   Tx[tid;`CURQBAR]:curqbar;
   };
   
update_bar_table_ctaacd:{[tid;firstprice]
	h:Tx[tid];
	curqbar:h`CURQBAR;
	barcnt:h`BARCNT;
	his_bar_dict:h`HIS_BAR_DICT;
	(his_bar_dict`llbar):his_bar_dict`lbar;
	(his_bar_dict`lbar):value curqbar;
    Tx[tid;`HIS_BAR_DICT]:his_bar_dict;
	//以下部分为每日前OBVWINDOW个bar更新HH，LL；
	$[h`UPDATEPARAM;
		[
		if[barcnt=0i; //If(time*Timebase == NewDayStartTime)
			Tx[tid;`HH]:firstprice;
			Tx[tid;`LL]:firstprice;
			Tx[tid;`DHigh]:firstprice;
			Tx[tid;`DLow]:firstprice;
			Tx[tid;`StoppedLong]:0b;
			Tx[tid;`StoppedShrt]:0b;
			Tx[tid;`BARCNT]:barcnt+1;];
		if[(barcnt>0i)&(barcnt<h`OBVWINDOW);  //If(CurrentBar>=ObvStartBarCnt && CurrentBar<=ObvStartBarCnt+ObvWindow) 
			Tx[tid;`HH]:$[curqbar[`highpx]>h`HH;curqbar[`highpx];h`HH];
			Tx[tid;`LL]:$[curqbar[`lowpx]<h`LL;curqbar[`lowpx];h`LL];
			Tx[tid;`BARCNT]:barcnt+1;
			if[(barcnt+1)>=h`OBVWINDOW;Tx[tid;`UPDATEPARAM]:0b;Tx[tid;`ENABLEORDER]:1b;];];
		];
        //else{If(Low < DLow)  DLow = Low; If(High > DHigh) DHigh = High;}
		[Tx[tid;`DHigh]:$[curqbar[`highpx]>h`DHigh;curqbar[`highpx];h`DHigh]; 
		Tx[tid;`DLow]:$[curqbar[`lowpx]<h`DLow;curqbar[`lowpx];h`DLow];	
		]	
	];
    };

//update_long_short_condition for open;
update_long_short_condition_ctaacd:{[tid]
	if[not check_time_status_open_ctaacd[tid];:()];
	closepx_position:1;
	h:Tx[tid];
	if[h[`POSITION]<>0;:()];
	curqbar:h`CURQBAR;
	his_bar_dict:h`HIS_BAR_DICT
	openpx:curqbar[`openpx];
	lastclosepx:(his_bar_dict`lbar)[closepx_position]; 
	llastclosepx:(his_bar_dict`llbar)[closepx_position];
	Tx[tid;`LSFLAG]:$[(openpx>lastclosepx)&(openpx>llastclosepx)&(llastclosepx>h[`HH])&(0b=h`StoppedLong);1i;
					(openpx<lastclosepx)&(openpx<llastclosepx)&(llastclosepx<h[`LL])&(0b=h`StoppedShrt);-1i;
					0i];
	};
		
//update_long_short_condition for close;
update_close_condition_ctaacd:{[tid]
	if[not check_time_status_close_ctaacd[tid];:()];
	h:Tx[tid];
	curqbar:h`CURQBAR;
	placenum:h`PlaceNum;
	lowpx:curqbar[`lowpx];
	highpx:curqbar[`highpx];
	Tx[tid;`LSFLAG]:$[(h[`POSITION]=placenum)&(lowpx<h[`HH]-h[`A]);-1i;
					(h[`POSITION]=-1f*placenum)&(highpx>h[`LL]+[`A]);1i;
		             0i];
	};	

//update_long_short_condition for force cover;
update_forcecover_condition_ctaacd:{[tid]
	h:Tx[tid];
	if[not h`EnableForceCover;:()];
	if[not check_time_status_forcecover_ctaacd[tid];:()];
	Tx[tid;`LSFLAG]:$[(h[`POSITION]=placenum)&(h[`ENABLEORDER]=1b);-1i;
					(h[`POSITION]=-1f*placenum)&(h[`ENABLEORDER]=1b);1i;
		             0i];
	};

// Place future order. product:`HQ1 qty:1f
place_fut_order_ctaacd:{[tid;product;qty;longshortflag]
	h:Tx[tid];
	placenum:h`PlaceNum;
    futcode:h`FUT;
    futacc:(h`OPENACCT)[product;`stkacc];
    postable:select from P where trader=tid,account=futacc,fsym=futcode;
    totalqty:0f^first exec qty from postable;
    longqty:0f^first exec longqty from postable;
    shortqty:0f^first exec shortqty from postable;
    slipprice:(h`FUTSLIPPOINT)*QX[futcode;`pxunit];
    futask:round_to_unit_px_ctaacd[tid;futcode;QX[futcode;`o1px]+slipprice];
    futbid:round_to_unit_px_ctaacd[tid;futcode;QX[futcode;`b1px]-slipprice];
    if[(longshortflag=0i);stop_strategy_ctaacd[tid];write_logs_ctaacd[tid;-3!("Time:";now[];"Error:Zero long short flag.")];:()];
    orderid:$[(longshortflag>0i);limit_buyx[futacc;tid;futcode;qty;futask;`ctaacd_buy];
								 limit_sellx[futacc;tid;futcode;qty;futbid;`ctaacd_sell];
								]; 
    Tx[tid;`FUTID]:orderid;
    };

// Execute orders according to lsflag.    
execute_orders_ctaacd:{[tid]
    h:Tx[tid];
	longshortflag:h`LSFLAG;
	if[longshortflag=0i;:()];
	futqty:h`PlaceNum;
    targetproduct:h`CURPRODUCT;
    if[longshortflag<>0i;
                place_fut_order_ctaacd[tid;targetproduct;futqty;longshortflag];  
                Tx[tid;`ENABLEORDER]:0b;
                write_logs_ctaacd[tid;-3!("Execute order, LSFlag:";longshortflag;"time";now[];)];
        ];
    };	

// Update order table in filled status.  orderid:`10007 update_order_table_in_filled_status_ctaacd[`cta;`10007]
update_order_table_in_filled_status_ctaacd:{[tid;orderid]
        h:Tx[tid];
		placenum:O[orderid;`cumqty];
		$[(O[orderid;`side]=.enum.BUY)&(O[orderid;`posefct]=.enum`OPEN);Tx[tid;`POSITION]:h[`POSITION]+placenum;
		  (O[orderid;`side]=.enum.SELL)&(O[orderid;`posefct]=.enum`OPEN);Tx[tid;`POSITION]:h[`POSITION]-placenum;
		  (O[orderid;`side]=.enum.SELL)&(O[orderid;`posefct]=.enum.CLOSE);[Tx[tid;`POSITION]:h[`POSITION]-placenum;Tx[tid;`StoppedLong]:1b;];
		  (O[orderid;`side]=.enum.BUY)&(O[orderid;`posefct]=.enum.CLOSE);[Tx[tid;`POSITION]:h[`POSITION]+placenum;Tx[tid;`StoppedShrt]:1b;];
		  :()
		];
		Tx[tid;`ENABLEORDER]:1b;
        Tx[tid;`CTARESSTATUS]:`$.enum`FILLED;
        Tx[tid;`LSFLAG]:0i;
		Tx[tid;`FUTID]:`;
    };

// Update order table when order is in cancelled status.
update_order_table_in_cancelled_status_ctaacd:{[tid;orderid]
    h:Tx[tid];
    longshortflag:h`LSFLAG;
	targetproduct:h`CURPRODUCT;
    futqty:(O[orderid;`qty]-O[orderid;`cumqty]);
    $[check_strategy_status_ctaacd[tid];
        [ 
	    place_fut_order_ctaacd[tid;targetproduct;futqty;longshortflag];  // place future order.
	    Tx[tid;`RETRYCNT]:(0i^h[`RETRYCNT])+1i;  
        ];
        write_logs_ctaacd[tid;-3!("Forbid to retry order as strategy was stopped,orderid:";orderid;now[])];
    ];
    };

// Check order pending or error canceling status.orderid:`10491
check_pending_order_ctaacd:{[tid;orderid]
    h:Tx[tid];
    timeoutunit:0.5f;millisecondbase:1000f;initretrycnt:0i;
    eclipsedseconds:(`long$(`time$now[]-`time$O[orderid;`createtime]))%millisecondbase;
    eclipsedcancelseconds:(0j^(`long$(`time$now[]-`time$O[orderid;`canceltime])))%millisecondbase;
    timeoutseconds:timeoutunit*h`TIMEOUTCNT;
    
    status:O[orderid;`status];
    cancelstatus:O[orderid;`cancelstatus];
   
    if[(status in .enum`NEW`PARTIALLY_FILLED)&(eclipsedseconds>=timeoutseconds);mcxl orderid;;write_logs_ctaacd[tid;-3!("Pending order was found,orderid:";orderid)];];
    if[(Tx[tid;`RETRYCNT]>=h`MAXRETRYCNT);stop_strategy_ctaacd[tid];write_logs_ctaacd[tid;-3!("Stopped by timer on retry max retry times.orderid:";orderid)]];
    if[((status=.enum`PENDING_NEW)&(eclipsedseconds>=timeoutseconds))|((cancelstatus=.enum`PENDING_CANCEL)&(eclipsedcancelseconds>=timeoutseconds));stop_strategy_ctaacd[tid];write_logs_ctaacd[tid;-3!("Stop on pending order, id:";orderid)]];
    };
	

// Triggerd by quote.tid:`cta
onq_ctaacd:{[tid;y]
    h:Tx[tid];
    timedelay:.ctaacd.timedict`TIME_DELAY;
    if[(now[]<timedelay+SysCtrl[`SYSSTART]);:()];
    if[fut_price_filter_ctaacd[tid];:()];
    if[(Tx[tid;`LASTTICKTIME]<>QX[h[`SYMS];`time])&(check_time_status_open_ctaacd[tid]);
    	Tx[tid;`LASTTICKTIME]:QX[h[`SYMS];`time];
		update_quote_dict_ctaacd[tid]; 
		if[h[`WATCHMOD]=0b;
			if[h[`ENABLEORDER]=1b;
				update_long_short_condition_ctaacd[tid];
				//update_close_condition_ctaacd[tid];
				update_forcecover_condition_ctaacd[tid];
				execute_orders_ctaacd[tid];   	
			  ];
			update_close_condition_ctaacd[tid];
			execute_orders_ctaacd[tid]; 
		];
    ];    
	};
	
// Triggered by new order status.
ono_ctaacd:{[tid;orderid]
    if[(T[tid;`active]=0b)|(T[tid;`stop]=`d)|(T[tid;`stop]=`r);:()];
    h:Tx[tid];
	status:O[orderid;`status];
    fsym:O[orderid;`fsym];
    if[status=.enum.NULL;write_logs_ctaacd[tid;-3!("Order status is NULL,orderid:";orderid;"time:";now[])];stop_strategy_ctaacd[tid]];
    if[status=.enum`REJECTED;write_logs_ctaacd[tid;-3!("Stop on rejected order:";orderid;"time:";now[])];stop_strategy_ctaacd[tid]];
    if[status=.enum`FILLED;update_order_table_in_filled_status_ctaacd[tid;orderid]];
    if[status=.enum`CANCELED;update_order_table_in_cancelled_status_ctaacd[tid;orderid]];
	};
    
// Triggered by timer.
ont_ctaacd:{[tid;time]    
    if[0b=check_strategy_status_ctaacd[tid];
       // Risk control is triggered.
       if[(T[tid;`stop]=`r)&(T[tid;`active]=1b);T[tid;`active]:0b;Tx[tid;`AGTWORKSTATUS]:0b;Tx[tid;`AGTRESSTATUS]:`$.enum`STOPPED;];
       :()];
    h:Tx[tid];
    enableretryorder:h`ENABLERETRYORDER;
    if[(enableretryorder=1b);
        check_pending_order_ctaacd[tid;h`FUTID];
    ];
   };

// Triggered by day.
ond_ctaacd:{[tid;date]
	if[`CLOSED=SysCtrl`TESTATUS;:()];
	// Save Tx table to local db.
	filepath:((string SysOpt[`RDB]),"/",string Me),"/";
	sfarbfilepath:`$(filepath,"Tx",(string tid));
	sfarbfilepath set Tx[tid];
	write_logs_ctaacd[tid;-3!("Save ond,time:";now())];
	Tx[tid;`LASTTICKTIME]:.z.T;
	// Enable calculation of the paramters.
	reset_param_for_ond[tid];
	Tx[tid;`A]:(Tx[tid;`DHigh]-Tx[tid;`DLow])%(.ctaacd.paramdict[`stoplossfactor]); 

    };

//reset for new day
reset_param_for_ond:{[tid]
	Tx[tid;`UPDATEPARAM]:1b;
	Tx[tid;`ENABLEORDER]:0b;
	Tx[tid;`StoppedLong]:0b;
	Tx[tid;`StoppedShrt]:0b;
	Tx[tid;`BARCNT]:0i;
	Tx[tid;`HIS_BAR_DICT]:.ctaacd.his_bar_dict;
	Tx[tid;`CURQBAR]:.ctaacd.quote_bar_dict_ctaacd;
    write_logs_ctaacd[tid;-3!("Time:";now[];"reset_param_for_ond.")];
	};	
// Stop strategy.
stop_strategy_ctaacd:{[tid]
	T[tid;`active]:0b;
	if[T[tid;`stop]<>`r;T[tid;`stop]:`d];
	Tx[tid;`CTAWORKSTATUS]:0b;
	Tx[tid;`CTARESSTATUS]:`$.enum`REJECTED;
	};

//active_strategy_ctaacd[tid] tid:`cta
active_strategy_ctaacd:{[tid]
	T[tid;`active]:1b;
	T[tid;`stop]:`;
	Tx[tid;`CTAWORKSTATUS]:1b;
	Tx[tid;`CTARESSTATUS]:`;
	Tx[tid;`ENABLEORDER]:1b;
	Tx[tid;`LSFLAG]:0i;
	};

/
open_acc_table_ctaacd:1!select distinct product,stkacc from ACC where product in `HQ1`HQ2;
quote_bar_dict_ctaacd:(`openpx`closepx`highpx`lowpx)!(0ne;0ne;0ne;0ne);
//HISBAR_CTAACD:([time:`time$()]openpx:`real$(); closepx:`real$();highpx:`real$();lowpx:`real$()); 
his_bar_dict:(`llbar`lbar)!((0ne;0ne;0ne;0ne);(0ne;0ne;0ne;0ne));
clt_agt:`cta;orderacc:`its1;targetetf:`510500.XSHG;agt_strategy_syms:`510500.XSHG;
smkx[`;`TSINIT;`id`active`isreal`style`account`event`tspara`syms`cash!(clt_agt;0b;1b;`intraday;orderacc;`QUPD`OUPD`TUPD`DUPD`IUPD`EUPD!`onq_ctaacd`ono_ctaacd`ont_ctaacd`ond_ctaacd`oni_ctaacd`one_ctaacd;
(`WATCHMOD`CTAWORKSTATUS`CTARESSTATUS`EnableForceCover`CURPRODUCT`OPENACCT`FREQ`LASTBARMM`PlaceNum`FUT`FUTID`ACCT`LSFLAG`BARCNT`OBVWINDOW`UPDATEPARAM`HH`LL`A`DHigh`DLow`FUTSLIPPOINT`POSITION`StoppedLong`StoppedShrt`ENABLERETRYORDER`RETRYCNT`MAXRETRYCNT`TIMEOUTCNT`LASTTICKTIME`ENABLEORDER`HIS_BAR_DICT`CURQBAR)!
(1b;1b;"";0b;`HQ1;open_acc_table_ctaacd;5i;0i;4f;`IF1612.CCFX;`;orderacc;0i;0i;5i;0b;0e;0e;0e;0e;0e;10i;0f;0b;0b;0b;0i;5i;0i;0Nt;1b;his_bar_dict;quote_bar_dict_ctaacd);agt_strategy_syms;2e9)]; 
