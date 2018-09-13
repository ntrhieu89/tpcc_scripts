import os
import sys

# produce the anas.txt file
# generate file to create throughput and latency graph
path=sys.argv[1]

files = os.listdir(path)

throughput=""

latency_NewOrder=""
avrlatency_NewOrder=0
no=0

latency_Payment=""
avrlatency_Payment=0
p=0

latency_Delivery=""
avrlatency_Delivery=0
d=0

latency_OrderStatus=""
avrlatency_OrderStatus=0
os=0

latency_StockLevel=""
avrlatency_StockLevel=0
sl=0

for fname in files:
	fname=path+"/"+fname
	# generate throughput file
	if '.res' in fname:
		with open(fname) as f:
    			content = f.readlines() 
			for line in content:
				throughput += line.split(",")[1]+"\n"

	if '.csv' in fname:
		with open(fname) as f:
			content = f.readlines()
			for line in content:
				#print line
				try:
					transName = line.split(",")[1];
					latency = line.split(",")[3];
				except:
					print "error parsing "+line

				if transName == "NewOrder":
					latency_NewOrder += latency + "\n"
					avrlatency_NewOrder += int(latency)
					no +=1
                                if transName == "Payment":
                                        latency_Payment += latency + "\n"
                                        avrlatency_Payment += int(latency)
					p += 1
                                if transName == "Delivery":
                                        latency_Delivery += latency + "\n"
                                        avrlatency_Delivery += int(latency)
					d += 1
                                if transName == "OrderStatus":
                                        latency_OrderStatus += latency + "\n"
                                        avrlatency_OrderStatus += int(latency)
					os += 1
                                if transName == "StockLevel":
                                        latency_StockLevel += latency + "\n"
                                        avrlatency_StockLevel += int(latency)
					sl +=1
				
with open(path+"/throughput.txt", "w") as text_file:
	text_file.write(throughput)

with open(path+"/NewOrder.txt", "w") as text_file:
        text_file.write(latency_NewOrder)
with open(path+"/Payment.txt", "w") as text_file:
        text_file.write(latency_Payment)
with open(path+"/Delivery.txt", "w") as text_file:
        text_file.write(latency_Delivery)
with open(path+"/OrderStatus.txt", "w") as text_file:
        text_file.write(latency_OrderStatus)
with open(path+"/StockLevel.txt", "w") as text_file:
        text_file.write(latency_StockLevel)

anas=""
anas += "Average NewOrder latency = "+ str(avrlatency_NewOrder / float(no) / 1000)+"\n"
anas += "Average Payment latency = "+ str(avrlatency_Payment / float(p) / 1000)+"\n"
anas += "Average Delivery latency = "+ str(avrlatency_Delivery / float(d) / 1000)+"\n"
anas += "Average OrderStatus latency = "+ str(avrlatency_OrderStatus / float(os) / 1000)+"\n"
anas += "Average StockLevel latency = "+ str(avrlatency_StockLevel / float(sl) / 1000)+"\n"

with open(path+"/anas.txt", "w") as text_file:
        text_file.write(anas)



