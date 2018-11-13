#!/usr/bin/python
#import matplotlib
import matplotlib
matplotlib.use('Agg')
import numpy as np
import matplotlib.pyplot as plt
import sys
#matplotlib.use('Agg')

file = sys.argv[1]
outputfile = sys.argv[2] 
f = open(sys.argv[1])
data = f.read()

data = data.splitlines()
colnum = len(data[0].split(',')) - 1
if colnum ==0:
	colnum=1

headers = data[0].split(',')
start = 1

cols = []
for c in range(0, colnum):
	cols.append([row.split(',')[c] for row in data[start:]])

figMR = plt.figure()
axMR = figMR.add_subplot(111)
axMR.set_title(file.upper()[file.rfind("/")+1:file.rfind(".")])
axMR.set_xlabel('Time')
if 'cpu' in file:
	axMR.set_ylabel('%Utilization')	
	plt.ylim( 0, 100 )
if 'mem' in file:
	axMR.set_ylabel('available MB')
	plt.ylim( 0, 63000 )
if 'net' in file:
	axMR.set_ylabel('MB/sec')
	plt.ylim( 0, 100 )		
if 'disk' in file:
	axMR.set_ylabel('Queue length')		
if 'diskRW' in file:
	axMR.set_ylabel('Number of sectors/sec')

xAxis = []
for i in range(0, len(cols[0])):
	xAxis.append(i)	
i=0
for col in cols:
	stri = 'client'+str(i)
	axMR.plot(xAxis, col, label= headers[i])
	i=i+1
if 'disk' in file:
	ymin, ymax = plt.ylim()
	if ymax < 5:
		plt.ylim( 0, 5 )

art = []
lgd = axMR.legend(loc=9, bbox_to_anchor=(0.5, -0.1))
art.append(lgd)
plt.savefig(outputfile+'.png',additional_artists=art, bbox_inches="tight")
print 'Created ' + outputfile + '.png'



