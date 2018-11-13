import os
import sys

folder=sys.argv[1]

exps = os.listdir(folder)

def getCacheStats(path, stat_name):
	with open(file) as f:
		contents = f.readlines()
		for i in range(0, len(contents)):
			line = contents[i]
			if stat_name in line:
				return int(line.split(" ")[2])
	return 0

res = ''
res += 'exp_name,nclis,throughput,new_order,new_order_abort,payment,payment_abort,delivery,delivery_abort,order_status,order_status_abort,stock_level,stock_level_abort,applied_sessions,bw_size,bytes_allocated,get_from_bdb,deque_from_bdb,put_in_bdb,async_put_in_bdb,evict_to_bdb,delete_in_bdb\n'
for exp in exps:
	print "Experiment "+exp

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

	total_bytes_allocated=0
	total_get_from_bdb=0
	total_deque_from_bdb=0
	total_put_in_bdb=0
	total_async_put_in_bdb=0
	total_evict_to_bdb=0
	total_delete_in_bdb=0
	
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
						#print line
						totalThroughput += float(line.split(' ')[11])
					if 'NewOrder' in line or 'Payment' in line or 'Delivery' in line or 'OrderStatus' in line or 'StockLevel' in line:

						#print line
						for j in range(0, 3):
							linex = contents[i+j+1]
							#print linex
							if 'commit' in linex:
								commit = float(linex.split(': ')[1].replace(",", ""))
								print commit
							elif 'aboort' in linex:
								abort = float(linex.split(': ')[1])
								print abort

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
						print line
						y = line.split(": ")[1].split(",")[0]
						print y
						totalAppliedSessions += float(y)
						print "xxxxx "+str(totalAppliedSessions)
					if 'bw_size' in line:
						totalBWSize += int(line.split(": ")[1].split(",")[0])
		if 'cachestats' in fname:
			total_bytes_allocated += getCacheStats(fname, 'bytes_allocated')
			total_get_from_bdb += getCacheStats(fname, 'get_from_bdb')
			total_deque_from_bdb += getCacheStats(fname, 'deque_from_bdb')
			total_put_in_bdb += getCacheStats(fname, 'put_in_bdb')
			total_async_put_in_bdb += getCacheStats(fname, 'async_put_in_bdb')
			total_evict_to_bdb += getCacheStats(fname, 'evict_to_bdb')
			total_delete_in_bdb += getCacheStats(fname, 'delete_in_bdb')


	res += exp+','+str(x)+","+str(int(totalThroughput))+','+str(int(totalNewOrder))+','+str(int(totalNewOrderAbort))+','+str(int(totalPayment))+','+str(int(totalPaymentAbort))+','+str(int(totalDelivery))+','+str(int(totalDeliveryAbort))+','+str(int(totalOrderStatus))+','+str(int(totalOrderStatusAbort))+','+str(int(totalStockLevel))+','+str(int(totalStockLevelAbort))+","+str(int(totalAppliedSessions))+","+str(totalBWSize)+","+str(total_bytes_allocated)+","+str(total_get_from_bdb)+","+str(total_deque_from_bdb)+","+str(total_put_in_bdb)+","+str(total_async_put_in_bdb)+","+str(total_evict_to_bdb)+","+str(total_delete_in_bdb)+"\n"
	print res


