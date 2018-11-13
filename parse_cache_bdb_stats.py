import os
from pprint import pprint
import sys

def readable_exp_func(exp):
    ems=exp.split("-")
    wid=ems[5]

    cache_size=ems[-3]
    repl=ems[-5]
    config=ems[-7]
    return "w-{}-config-{}-cs-{}-repl-{}-".format(wid, config, cache_size, repl)

def parse_exp(exps_dir, result_dir):
    stats={}
    for f in os.listdir(exps_dir + '/' + result_dir):
        if "cachestats" not in f:
            continue
        # print exps_dir + '/' + result_dir + '/' + f
        file = open(exps_dir + '/' + result_dir + '/' + f, 'r')
        lines = file.readlines()
        for line in lines:
            if "bdb" not in line:
                continue
            ems = line.split(" ")
            # print ems
            if ems[1] not in stats:
                stats[ems[1]] = 0
            stats[ems[1]] += int(ems[2].replace("\n",""))
        file.close()
    return stats

def parse_all_exps(exps_dir):
    exp_stats = {}
    out="get_from_bdb,deque_from_bdb,put_in_bdb,async_put_in_bdb,async_put_bw_in_bdb,evict_to_bdb,delete_in_bdb,partial_store_in_bdb"
    metrics=out.split(",")
    out=","+out+"\n"
    for exp_dir in os.listdir(exps_dir):
        if "try" not in exp_dir:
            continue
        stats = parse_exp(exps_dir, exp_dir)
        readable_exp=readable_exp_func(exp_dir)
        exp_stats[readable_exp] = stats
        out+=exp_dir
        out+=","
        for metric in metrics:
            if metric in stats:
                out+=str(stats[metric])
                out+=","
            else:
                out+="-1,"
        out+="\n"
    print out
    return exp_stats

def sumup(folder):
    res = ''
    results={}
    for exp in os.listdir(folder):
        # print "Experiment "+exp

        if 'bdb' not in exp:
            continue

        path=folder+"/"+exp
        files = os.listdir(path)

        totalThroughput=0.0
        totalNewOrder=0.0
        totalNewOrderAbort=0.0
        totalPayment=0.0
        totalPaymentAbort=0.0
        totalDelivery=0.0
        totalDeliveryAbort=0.0
        totalOrderStatus=0.0
        totalOrderStatusAbort=0.0
        totalStockLevel=0.0
        totalStockLevelAbort=0.0
        totalAppliedSessions=0.0
        x = 0
        totalBWSize = 0
        
        for fname in files:
            file=path+"/"+fname

            if 'output' in fname:
                with open(file) as f:
                    contents = f.readlines()
                    for i in range(0, len(contents)):
                        line = contents[i]
                        commit=0.0
                        abort=0.0
        
                        if 'Missed keys' in line:
                            continue

                        if 'Rate limited' in line:
                            x += 1
                            
                            totalThroughput += float(line.split(' ')[11])
                        if 'NewOrder' in line or 'Payment' in line or 'Delivery' in line or 'OrderStatus' in line or 'StockLevel' in line:

                            
                            for j in range(0, 3):
                                linex = contents[i+j+1]
                                
                                if 'commit' in linex:
                                    commit = float(linex.split(': ')[1].replace(",", ""))
                                    # print commit
                                elif 'aboort' in linex:
                                    abort = float(linex.split(': ')[1])
                                    # print abort

                            if 'NewOrder' in line:
                                totalNewOrder += commit
                                totalNewOrderAbort += abort
                            elif 'Payment' in line:
                                totalPayment += commit
                                totalPaymentAbort += abort     
                            elif 'Delivery' in line:
                                totalDelivery += commit
                                totalDeliveryAbort += abort
                            elif 'OrderStatus' in line:
                                totalOrderStatus += commit
                                totalOrderStatusAbort += abort
                            elif 'StockLevel' in line:
                                totalStockLevel += commit
                                totalStockLevelAbort += abort
                        if 'applied_sessions' in line:
                            totalAppliedSessions += float(line.split(": ")[1].split(",")[0])
                        if 'bw_size' in line:
                            totalBWSize += int(line.split(": ")[1].split(",")[0])

        res += exp+','+str(x)+","+str(int(totalThroughput))+','+str(int(totalNewOrder))+','+str(int(totalNewOrderAbort))+','+str(int(totalPayment))+','+str(int(totalPaymentAbort))+','+str(int(totalDelivery))+','+str(int(totalDeliveryAbort))+','+str(int(totalOrderStatus))+','+str(int(totalOrderStatusAbort))+','+str(int(totalStockLevel))+','+str(int(totalStockLevelAbort))+","+str(int(totalAppliedSessions))+","+str(totalBWSize)+"\n"
        
        readable_exp=readable_exp_func(exp)
        results[readable_exp]={}
        results[readable_exp]["Throughput"]=totalThroughput
        results[readable_exp]["NewOrder"]=totalNewOrder
        results[readable_exp]["NewOrderAbort"]=totalNewOrderAbort
        results[readable_exp]["Payment"]=totalPayment
        results[readable_exp]["PaymentAbort"]=totalPaymentAbort
        results[readable_exp]["Delivery"]=totalDelivery
        results[readable_exp]["DeliveryAbort"]=totalDeliveryAbort
        results[readable_exp]["OrderStatus"]=totalOrderStatus
        results[readable_exp]["OrderStatusAbort"]=totalOrderStatusAbort
        results[readable_exp]["StockLevel"]=totalStockLevel
        results[readable_exp]["StockLevelAbort"]=totalStockLevelAbort
        results[readable_exp]["AppliedSessions"]=totalAppliedSessions
        results[readable_exp]["BWSize"]=totalBWSize
    print res
    return results

def print_results(wid, repl, cs, cache_stats, exp_stats):
    valid_exps=[]
    for exp in cache_stats:
        if "w-{}-".format(wid) not in exp:
            continue
        if "repl-{}-".format(repl) not in exp:
            continue
        if "cs-{}-".format(cs) not in exp:
            continue
        valid_exps.append(exp)

    if len(valid_exps) == 0:
        return

    valid_exps.sort()
    out=""
    for exp in valid_exps:
        out+=exp
        out+=","
    print out
    for metric in metrics:
        out=""
        for exp in valid_exps:
            cache_metric=cache_stats[exp]
            exp_metric=exp_stats[exp]
            if metric in exp_metric:
                out+=str(exp_metric[metric])
                out+=","
            if metric in cache_metric:
                out+=str(cache_metric[metric])
                out+=","
        print out

def print_results_by_config(wid, repl, config, cache_stats, exp_stats):
    valid_exps={}
    for exp in cache_stats:
        if "w-{}-".format(wid) not in exp:
            continue
        if "repl-{}-".format(repl) not in exp:
            continue
        if "config-{}-".format(config) not in exp:
            continue
        valid_exps[int(exp.split("-")[-4])]=exp

    if len(valid_exps) == 0:
        return

    out=""
    for exp in sorted(valid_exps):
        out+=valid_exps[exp]
        out+=","
    print out
    for metric in metrics:
        out=""
        for exp in sorted(valid_exps):
            value=valid_exps[exp]
            cache_metric=cache_stats[value]
            exp_metric=exp_stats[value]
            if metric in exp_metric:
                out+=str(exp_metric[metric])
                out+=","
            if metric in cache_metric:
                out+=str(cache_metric[metric])
                out+=","
        print out

exps_dir=sys.argv[1]
cache_stats=parse_all_exps(exps_dir)
exp_stats=sumup(exps_dir)

metrics=["Throughput", "NewOrder", "NewOrderAbort", "Payment", "PaymentAbort", "Delivery", "DeliveryAbort", "OrderStatus", "OrderStatusAbort", "StockLevel", "StockLevelAbort", "BWSize", "AppliedSessions","get_from_bdb", "delete_in_bdb", "put_in_bdb", "async_put_in_bdb", "async_put_bw_in_bdb", "partial_store_in_bdb", "evict_to_bdb", "deque_from_bdb"]
print metrics
out=""
for m in metrics:
    out+=m
    out+=","
print out

cs=6000
for wid in [1, 10, 100]:
    for repl in [1, 2, 3]:
        print_results(wid, repl, cs, cache_stats, exp_stats)

for wid in [1, 10, 100]:
    for repl in [1, 2, 3]:
        for config in ["async_bdb", "sync_bdb"]:
            print_results_by_config(wid, repl, config, cache_stats, exp_stats)