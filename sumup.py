import os
import sys

folder=sys.argv[1]

exps = os.listdir(folder)

res = ''
for exp in exps:
	print "Experiment "+exp

	if 'cache' not in exp:
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
	
	for fname in files:
		file=path+"/"+fname

		if 'output' in fname:
			with open(file) as f:
				contents = f.readlines()
				for i in range(0, len(contents)):
					line = contents[i]
					commit=0.0
					abort=0.0

					if 'Rate limited' in line:
						x += 1
						print line
						totalThroughput += float(line.split(' ')[11])
					if 'NewOrder' in line or 'Payment' in line or 'Delivery' in line or 'OrderStatus' in line or 'StockLevel' in line:

						print line
						for j in range(0, 3):
							linex = contents[i+j+1]
							print linex
							if 'commit' in linex:
								commit = float(linex.split(': ')[1])
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
						totalAppliedSessions += float(line.split(": ")[1].split(",")[0])

	res += exp+','+str(x)+","+str(int(totalThroughput))+','+str(int(totalNewOrder))+','+str(int(totalNewOrderAbort))+','+str(int(totalPayment))+','+str(int(totalPaymentAbort))+','+str(int(totalDelivery))+','+str(int(totalDeliveryAbort))+','+str(int(totalOrderStatus))+','+str(int(totalOrderStatusAbort))+','+str(int(totalStockLevel))+','+str(int(totalStockLevelAbort))+","+str(int(totalAppliedSessions))+"\n"
	print res


