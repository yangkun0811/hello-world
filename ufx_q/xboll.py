# -*- coding: utf-8 -*-
# This strategy is CX_BOLL_5min.
# Author Chen,Xu, 20151001.

from __future__ import division

strategy_name = 'xboll'
import trade, bardata,strategylib,numpy
import contractdict as cd

T = trade.TradeObj()
B = bardata.BarObj()
SL = strategylib.strategylib()

settle_date_list = cd.ic_over_settle_date_list
settle_cnt       = 1
cur_settle_date  = settle_date_list[0]
next_settle_date = settle_date_list[1]
force_cover_flag = 0
order_validate_status = 1
cover_date = 0

# Define the bar index for index movement control.
bar_index = -1

# params
Length                  = 18;
Offset                  = 2;
PlaceNum                = 1;
NotBeforeTime           = 930;
NotAfterTime            = 1450;
StopLossPoint           = 14;
StopProfitLimitPoint    = 20;
StopProfitPoint         = 10;
bollwidth               = 9;
WRLength                = 6;
OverSold                = 16;
OverBought              = 90;
SlipPoint               = 1;

# Vars
UpLine              = [0,0];
DownLine            = [0,0];
MidLine             = [0,0];
Band                = [0,0];
WRValue             = [0,0];
StopLossLimitNum    = 50;
isReverseThrough    = 0;
YesterdayClosePrice = 0;
Timefactor          = 10000;
Hourfactor          = 100;

data_length = 0
bar_secs    = 900
bar_length = Length+1;
global_var_1 = 0;
global_var_2 = 0;
global_var_3 = 0;

ContractCode = 'IC00'
is_first_month_start_order = 0

def move_Index_of_Lists():

    global UpLine,DownLine,MidLine,Band,WRValue

    UpLine[1]   = UpLine[0]
    DownLine[1] = DownLine[0]
    MidLine[1]  = MidLine[0]
    Band[1]     = Band[0]
    WRValue[1]  = WRValue[0]

def set_global_test_param(param_dict):
    pass

def set_bar_param(seconds,bar_lengh):
    B.set_bar_length(bar_lengh)
    B.set_bar_seconds(seconds)

# Calc WR index in WRLength.
# W%R=100*(1-（Hn—C）÷（Hn—Ln）)
def PercentR(wrlength):
    Hn = SL.get_highest_in_list(B.high,WRLength)
    Ln = SL.get_lowest_in_list(B.low,WRLength)
    C  = B.close[0]
    first_diff = 0
    if Hn-Ln == 0:
        first_diff = Hn
        for item in B.high:
            if item <> Hn:
                first_diff = item

    if Hn-Ln == 0 and first_diff >= Hn:
        return 0
    elif Hn-Ln == 0 and first_diff < Hn:
        return 100
    else:
        return 100*(1-(Hn-C)/(Hn-Ln))

def AverageFC(input_list,length):
    assert len(input_list) >= length
    num = len(input_list)
    sum_score = sum(input_list)
    return sum_score/num

# 样本方差，/(n-1)
def StandardDev(input_list,length):
    return numpy.array(input_list).std(ddof=1)

def reset_all_global_vars():
    global UpLine,DownLine,MidLine,Band,WRValue,StopLossLimitNum,isReverseThrough,YesterdayClosePrice
    global data_length,bar_secs

    B.reset_data()
    set_bar_param(bar_secs, bar_length)
    UpLine              = [0,0];
    DownLine            = [0,0];
    MidLine             = [0,0];
    Band                = [0,0];
    WRValue             = [0,0];
    StopLossLimitNum    = 50;
    isReverseThrough    = 0;
    YesterdayClosePrice = 0;

def block_invalidate_data(quote_data_item):
    status = 1
    bidpx = quote_data_item[2]
    askpx = quote_data_item[3]
    if bidpx <= 1000 or askpx <= 1000:
        status = 0
    return status

def exec_force_cover(quote_data_item,order_validate_status):
    global SlipPoint,ContractCode
    global B,T
    Close = B.close[0]
    if T.market_position <> 0:
        placenum = abs(T.market_position)
        if T.market_position > 0:
            price = Close - SlipPoint
            T.sell(ContractCode, placenum, price, order_validate_status)
        elif T.market_position < 0:
            price = Close + SlipPoint
            T.buytocover(ContractCode, placenum, price, order_validate_status)
        print "10.date:%s,time:%s,Cover invalidate,price:%s,qty:%s,vstatus:%s" % (quote_data_item[0], quote_data_item[1], price, PlaceNum, order_validate_status)

def strategy_test(quote_data_item):

    global bar_index,isReverseThrough,YesterdayClosePrice,StopLossLimitNum,global_var_1,global_var_2,global_var_3
    global settle_date_list,cur_settle_date,next_settle_date,force_cover_flag,order_validate_status,settle_cnt,cover_date
    global is_first_month_start_order

    date_pos = 0
    curdate = quote_data_item[date_pos]

    #if curdate not in ['2016-11-18','2016-11-19','2016-11-20']:
    #    return

    if block_invalidate_data(quote_data_item) == 0:
        return

    if force_cover_flag == 1 and cover_date == curdate:
        return
    elif force_cover_flag == 1 and curdate <= cur_settle_date:
        order_validate_status = 0
    elif force_cover_flag == 1 and curdate > cur_settle_date:
        order_validate_status = 1
        force_cover_flag = 0
        cur_settle_date = next_settle_date
        settle_cnt += 1
        next_settle_date = settle_date_list[settle_cnt]
        is_first_month_start_order = 1
    try:
        # update and sync bar data.
        B.update_bar_data(quote_data_item)
    except Exception,e:
        print e

    # Refresh the list data.
    current_Bar_Index = B.current_bar()

    if current_Bar_Index <> bar_index:
        move_Index_of_Lists()
        bar_index = current_Bar_Index

    if bar_index <= Length:
        return

    time = B.convert_time_to_float(B.time[0])
    T.set_current_time(B.time[0])
    ###### 以下需要继续测试

    Open = B.open[0];Open_1 = B.open[1];
    High = B.high[0];High_1 = B.high[1];
    Low = B.low[0];Low_1 = B.low[1];
    Close = B.close[0];Close_1 = B.close[1];

    WRValue[0]  = PercentR(WRLength);
    MidLine[0]  = AverageFC(B.close[1:],Length);
    Band[0]     = StandardDev(B.close[1:],Length);
    UpLine[0]   = MidLine[0] + Offset * Band[0];
    DownLine[0] = MidLine[0] - Offset * Band[0];
    StopLossPoint = max(15,Offset * Band[0])

    if(B.date[0] != B.date[1]):
        # isReverseThrough = 0
        YesterdayClosePrice = B.close[1]
        StopLossLimitNum = 50
        global_var_1 = -1
        global_var_2 = -1

    short_order_status = 0

    # 空头开仓, 突破上轨，跌线开空, 信号闪烁
    if((time*Timefactor) >= NotBeforeTime and (time*Timefactor) < NotAfterTime):

        if UpLine[1] == 0 or DownLine[1]==0:
            return

        if(T.market_position == 0 and Close_1 >= UpLine[1] and UpLine[1]-DownLine[1]>=bollwidth):
            #price = Open-SlipPoint
            price = Close - SlipPoint
            T.sellshort(ContractCode,PlaceNum,price,short_order_status)
            global_var_3 = -1
            print "1.date:%s,time:%s,sellshort,price:%s,qty:%s,vstatus:%s"%(quote_data_item[0],quote_data_item[1],price,PlaceNum,short_order_status)
            return

        # 多头开仓,突破下轨，多线开多
        if(T.market_position == 0 and Close_1 <= DownLine[1] and UpLine[1]-DownLine[1]>=bollwidth):
            #price = Open+SlipPoint
            price = Close + SlipPoint
            T.buy(ContractCode,PlaceNum,price,order_validate_status)
            global_var_3 = 1
            print "2.date:%s,time:%s,buy,price:%s,qty:%s,vstatus:%s"%(quote_data_item[0],quote_data_item[1],price,PlaceNum,order_validate_status)
            return

        # 盘中止损反手 //and WRValue[1] <= OverSold // and WRValue[1] >= OverBought
        if(T.market_position >= 0 and (global_var_3 < 0 and global_var_1==time*Timefactor) or (global_var_1!=time*Timefactor and global_var_3 > 0 and  \
            (T.entryprice() - Low_1) >= StopLossPoint and StopLossLimitNum >0 and WRValue[0] <= OverSold)):
            StopLossLimitNum = StopLossLimitNum-1
            global_var_1 = time*Timefactor
            #price = max(Low-SlipPoint,min(Open-SlipPoint,(entry_price-StopLossPoint-SlipPoint)))
            price = Close - SlipPoint
            if is_first_month_start_order == 1:
                is_first_month_start_order = 0
                T.sell(ContractCode, PlaceNum, price, 0)
                print "cover first invalidate order."
            else:
                T.sell(ContractCode,PlaceNum, price,order_validate_status)
                #print "3.date:%s,time:%s,reverse sell,price:%s,qty:%s,vstatus:%s" % (quote_data_item[0], quote_data_item[1], price, PlaceNum, order_validate_status)
            T.sellshort(ContractCode,PlaceNum, price,short_order_status)
            global_var_3 = -1
            print "3.date:%s,time:%s,reverse sellshort,price:%s,qty:%s,vstatus:%s"%(quote_data_item[0], quote_data_item[1], price, PlaceNum,short_order_status)
            return

        elif(T.market_position <= 0 and (global_var_3 > 0 and global_var_1==time*Timefactor) or (global_var_1!=time*Timefactor and global_var_3 < 0 and \
            (High_1 - T.entryprice()) >= StopLossPoint and StopLossLimitNum >0 and WRValue[0] >= OverBought)):
            #price = min(High+SlipPoint,max(Open+SlipPoint,(entry_price+StopLossPoint+SlipPoint)))
            price = Close + SlipPoint
            if is_first_month_start_order == 1:
                is_first_month_start_order = 0
                T.buytocover(ContractCode, PlaceNum, price, 0)
                print "cover first invalidate order."
            else:
                T.buytocover(ContractCode, PlaceNum, price, short_order_status)
            T.buy(ContractCode,PlaceNum, price,order_validate_status)
            StopLossLimitNum = StopLossLimitNum-1
            global_var_1 = time*Timefactor
            global_var_3 = 1
            print "4.date:%s,time:%s,reverse buy,price:%s,qty:%s,vstatus:%s"%(quote_data_item[0], quote_data_item[1], price, PlaceNum,order_validate_status)
            return

        # 止盈
        if(T.market_position > 0 and global_var_3 > 0 and High_1 >= UpLine[1] and WRValue[1] <= OverSold and (High_1 - T.entryprice()) >= StopProfitPoint):
            #price = max(Low-SlipPoint,min(Open-SlipPoint,(entry_price+StopProfitPoint-SlipPoint)))
            price = Close - SlipPoint
            if is_first_month_start_order == 1:
                is_first_month_start_order = 0
                T.sell(ContractCode, PlaceNum, price, 0)
                print "cover first invalidate order."
            else:
                T.sell(ContractCode,PlaceNum,price,order_validate_status)
            isReverseThrough = 0
            global_var_3 = 0
            print "5.date:%s,time:%s,sell,price:%s,qty:%s,vstatus:%s"%(quote_data_item[0], quote_data_item[1], price, PlaceNum,order_validate_status)
            return;

        # 做空止盈
        if(T.market_position < 0 and global_var_3 < 0 and Low_1 <= DownLine[1] and WRValue[1] >= OverBought and (T.entryprice() - Low_1) >= StopProfitPoint):
            #price = min(High+SlipPoint,max(Open+SlipPoint,(entry_price-StopProfitPoint+SlipPoint)))
            price = Close + SlipPoint
            if is_first_month_start_order == 1:
                is_first_month_start_order = 0
                T.buytocover(ContractCode, PlaceNum, price, 0)
                print "cover first invalidate order."
            else:
                T.buytocover(ContractCode,PlaceNum,price,short_order_status)
            isReverseThrough = 0
            global_var_3 = 0
            print "6.date:%s,time:%s,buytocover,price:%s,qty:%s,vstatus:%s"%(quote_data_item[0], quote_data_item[1], price, PlaceNum,short_order_status)
            return;

        # 止盈反手
        if(isReverseThrough == 0 and global_var_3 > 0 and Close_1 > UpLine[0] and ((High - T.entryprice() ) > StopProfitLimitPoint)):
            isReverseThrough = 1

        if(isReverseThrough == 0 and global_var_3 < 0 and Close_1 < DownLine[0] and ((T.entryprice()  - Low) > StopProfitLimitPoint)):
            isReverseThrough = 1

        if(T.market_position >= 0 and (global_var_3 < 0 and global_var_2==time*Timefactor) or (global_var_2!=time*Timefactor and isReverseThrough == 1 and global_var_3 > 0  \
          and (High_1 - T.entryprice()) > StopProfitLimitPoint and Low <= MidLine[0])):
            #price = max(Low-SlipPoint,min(Open-SlipPoint,(MidLine[0]-SlipPoint)))
            price = Close - SlipPoint
            if is_first_month_start_order == 1:
                is_first_month_start_order = 0
                T.sell(ContractCode, PlaceNum, price, 0)
                print "cover first invalidate order."
            else:
                T.sell(ContractCode,PlaceNum, price,order_validate_status)
                #print "7.date:%s,time:%s,sell,price:%s,qty:%s,vstatus:%s" % (quote_data_item[0], quote_data_item[1], price, PlaceNum, order_validate_status)
            T.sellshort(ContractCode,PlaceNum, price,short_order_status)
            isReverseThrough = 0
            global_var_2 = time*Timefactor
            global_var_3 = -1
            print "7.date:%s,time:%s,sellshort,price:%s,qty:%s,vstatus:%s"%(quote_data_item[0], quote_data_item[1], price, PlaceNum,short_order_status)
            return

        elif(T.market_position <= 0 and (global_var_3 > 0 and global_var_2==time*Timefactor) or (global_var_2!=time*Timefactor and isReverseThrough == 1 and global_var_3 < 0 and \
                (T.entryprice() - Low_1) > StopProfitLimitPoint and High >= MidLine[0])):
            #price = min(High+SlipPoint,max(Open+SlipPoint,(MidLine[0]+SlipPoint)))
            price = Close + SlipPoint
            if is_first_month_start_order == 1:
                is_first_month_start_order = 0
                T.buytocover(ContractCode, PlaceNum, price, 0)
                print "cover first invalidate order."
            else:
                T.buytocover(ContractCode, PlaceNum, price, short_order_status)
            T.buy(ContractCode,PlaceNum,price,order_validate_status)
            isReverseThrough = 0
            global_var_2 = time*Timefactor
            global_var_3 = 1
            print "8.date:%s,time:%s,buy,price:%s,qty:%s,vstatus:%s" % (quote_data_item[0], quote_data_item[1], price, PlaceNum,order_validate_status)
            return

    # 收盘平仓 XBOLL
    if force_cover_flag == 0 and curdate == cur_settle_date and (time*Timefactor) >= NotAfterTime:
        if T.market_position <> 0:
            global_var_3 = 0
            if T.market_position > 0:
                #price = Open-SlipPoint
                price = Close - SlipPoint
                T.sell(ContractCode,PlaceNum,price,order_validate_status);
            elif  T.market_position < 0:
                #price = Open+SlipPoint
                price = Close + SlipPoint
                order_validate_status = order_validate_status
                T.buytocover(ContractCode,PlaceNum,price,short_order_status);
            print "9.date:%s,time:%s,Cover all,price:%s,qty:%s,vstatus:%s" % (quote_data_item[0], quote_data_item[1], price, PlaceNum,short_order_status)
        # 换月合约设置
        if force_cover_flag == 0 and curdate == cur_settle_date:
            force_cover_flag = 1
            cover_date = curdate
            reset_all_global_vars()


def strategy_main(quote_data):
    global T,data_length,bar_secs
    data_length = len(quote_data)
    T.account.strategyname = strategy_name
    set_bar_param(bar_secs,bar_length)
    for i in xrange(data_length):
        quote_data_item = quote_data[i]
        #print "quote_data_item:",quote_data_item
        strategy_test(quote_data_item)

        # test
        # if len(T.trade_result_list)>1 and (T.trade_result_list[-1])['time'] <> (T.trade_result_list[-2])['time']:
            #print T.trade_result_list[-1]
    print "strategy completed."
    return T