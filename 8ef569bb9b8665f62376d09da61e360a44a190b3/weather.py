#!/usr/bin/env python
# -*- coding: utf-8 -*-
import requests
from bs4 import BeautifulSoup
import datetime
import csv
import zipfile
import io
import pandas as pd
import json
import collections as cl
import os
import googlemaps
import urllib.error
import urllib.request

GOOGLE_MAP_API_KEY="AIzaSyCBPpt4PJauc94bnv5xC_yRDXSqPc4PlHw"

def geocoding(place):
	paths=["geocoding.csv","https://raw.githubusercontent.com/s1715-kudo/weather/gh-pages/geocoding.csv"]
	csvrs=[]
	mflag=True
	for path in paths:
		if(os.path.exists(path)):
			with open(path,mode="r",encoding="Shift-JIS") as f:
				reader=csv.reader(f)
				for row in reader:
					r=[]
					for i in range(len(row)):
						d=row[i]
						if(i!=0):
							d=float(d)
						r.append(d)
					csvrs.append(r)
				f.close()	
		if(len(csvrs)!=0):
			for i in csvrs:
				if(len(i)==3):
					if(i[0]==place):
						mflag=False
						return [i[1],i[2]]
	if(mflag):
		gmaps = googlemaps.Client(key=GOOGLE_MAP_API_KEY)
		geocode_result = gmaps.geocode(place)
		data = [place,geocode_result[0]["geometry"]["location"]["lat"],geocode_result[0]["geometry"]["location"]["lng"]]
		csvrs.append(data)
		
		with open(path,mode="w",newline="",encoding="Shift-JIS") as f:
			writer=csv.writer(f)
			for l in csvrs:
				writer.writerow(l)
			f.close()
		return [data[1],data[2]]

def nearDate(d,list):
	x=[abs(d-l) for l in list]
	return list[x.index(min(x))]

def stringDate(date):
	datestring=date
	now=datetime.datetime.now()
	year=[]
	month=[]
	if("月" in datestring):
		n=datestring.find("月")
		month.append(int(datestring[:n].replace("月","")))
		datestring=datestring[n+1:].replace("月","")
	day=int(datestring.replace("日",""))
	
	if(day==now.day and len(month)==0):
		month.append(now.month)
	if(len(month)!=0):
		if(month[0]==now.month):
			year.append(now.year)
	else:
		for i in range(3):
			m=now.month-1+i
			if(m==0):
				m=12
			elif(m==13):
				m=1
			month.append(m)
	if(len(year)==0):
		for i in range(3):
			year.append(now.year-1+i)
	date_l=[]
	for y in year:
		for m in month:
			try:
				date_l.append(datetime.datetime(y,m,day,0,0,0))
			except ValueError:
				pass
	return nearDate(now,date_l).strftime("%Y%m%d")
    
class AmeDAS(object):
	def __init__(self,name,point):
		if(not os.path.exists("amedas/")):
			os.mkdir("amedas/")
		self.point=int(point)
		self.name=name
		self.all=self.alldate()
		#self.csv_save(self.all[0])
		self.json_save(self.all)

	#一日分のデータ取得
	def data(self,date):
		datelist=['yesterday','today']
		url='https://www.jma.go.jp/jp/amedas_h/'+datelist[date]+'-'+str(self.point)+'.html'#URL
		column=26#縦列設定
		
		html=requests.get(url).content
		soup=BeautifulSoup(html, 'html.parser')
		title_text=soup.find(class_='td_title height2').get_text()
		
		#日付
		datetext=title_text[0:11]
		date_n=datetime.datetime.strptime(datetext,'%Y年%m月%d日').strftime('%Y%m%d')
		
		#場所
		location=self.location_import()
		
		#データ整理
		s0=soup.find(id='tbl_list').find_all('td')
		row=int(len(s0)/column)#横列設定
		list=[[s0[i*row+s].get_text().replace(u'\xa0','-').replace(u'休止中','-') for s in range(row)] for i in range(column)]
		for l in list:
			l.insert(0,date_n)
		
		del list[1];#2行目削除
		if(date==1):
			del list[0];#1行目削除
		else:
			list[0][0]="日付"
		return [list,location]

	#昨日と今日のデータの取得
	def alldate(self):
		l=[self.data(i) for i in range(2)]
		return [l[0][0]+l[1][0],l[0][1]]

	def location_import(self):
		dir="http://www.jma.go.jp/jma/kishou/know/amedas/ame_master.zip"
		r=requests.get(dir,stream=True)
		zip=zipfile.ZipFile(io.BytesIO(r.content),'r')
		for file in zip.namelist():
			with zip.open(file, 'r') as f:
				binaryCSV=f.read()
			df=pd.read_csv(io.BytesIO(binaryCSV),encoding='cp932')
			data=df[df["観測所番号"]==self.point]
			address=data["所在地"].values[0]
			if("　" in address):
				address=address[:address.find("　")]
			return [self.name,data["観測所名"].values[0].replace("\n",""),address,geocoding(address)]

	#csvデータを保存
	def csv_save(self,data):
		with open("amedas/"+self.name+".csv",mode='w',encoding='utf-8') as f:
			writer=csv.writer(f)
			for l in data:
				writer.writerow(l)
		f.close()
		
	#jsonデータを保存
	def json_save(self,data):
		data_location=data[1]
		data_weather=data[0]
		name_list=data_weather[0]
		cldata=cl.OrderedDict()
		cllocation=cl.OrderedDict()
		cllocation["名前"]=data_location[0]
		cllocation["観測所名"]=data_location[1]
		cllocation["所在地"]=data_location[2]
		cllocation["geocoding"]=data_location[3]
		cldata["場所"]=cllocation
		for i in range(len(data_weather)):
			if(i!=0):
				cld=cl.OrderedDict()
				str=""
				for j in range(len(name_list)):
					cld[name_list[j]]=data_weather[i][j]
					if(j==0 or j==1):
						d_str=data_weather[i][j]
						if(len(d_str)==1):
							d_str='0'+data_weather[i][j]
						str+=d_str
				cldata[str]=cld
		f=open("amedas/"+self.name+".json",'w',encoding="utf-8")
		json.dump(cldata,f,indent=4,ensure_ascii=False)
		f.close()
		
class forecast(object):
	def __init__(self,location):
		if(not os.path.exists("forecast/")):
			os.mkdir("forecast/")
		self.location=location
		self.icon_data=self.get_icon()
		self.all=self.data()
		self.json_save()
	
	def data(self):
		url="https://weathernews.jp/onebox/"+str(self.location[3][0])+"/"+str(self.location[3][1])+"/lang=ja"
		html=requests.get(url).content
		soup=BeautifulSoup(html, 'html.parser')
		dtl=[]
		datalist=[]
		s0=soup.find_all(class_='weather-day')
		head=soup.find_all(class_='weather-day__head')[0]
		headp=[i.get_text() for i in head.find_all("p")]
		headp[len(headp)-1]="風速"
		headp.append("風向")
		headp.insert(0,"日付")
		headp.insert(2,"icon")
		dtl.append(headp)
		for s1 in s0:
			dayd=s1.find(class_='weather-day__day').get_text()
			dayd=dayd[1:dayd.find("（")]
			dayd=stringDate(dayd)
			timedata=s1.find_all(class_='weather-day__item')
			for t0 in timedata:
				l0=[]
				l0.append(dayd)
				l0.append(t0.find(class_='weather-day__time').get_text())
				img=t0.find_all("img")[0]['src']
				if("dummy" in img):
					img=t0.find_all("img")[0]['data-original']
				if(not("https:" in img)):
					img="https:"+img
				l0.append(img)
				idata=self.get_img(img)
				l0.append(self.img_equals(idata))
				l0.append(t0.find(class_='weather-day__r').get_text().replace("℃","").replace("%","").replace("mm/h","").replace("m/s",""))
				l0.append(t0.find(class_='weather-day__t').get_text().replace("℃","").replace("%","").replace("mm/h","").replace("m/s",""))
				wind=t0.find(class_='weather-day__w').get_text()
				wn=wind.find("s")
				l0.append(wind[:wn+1].replace("℃","").replace("%","").replace("mm/h","").replace("m/s",""))
				l0.append(wind[wn+1:])
				dtl.append(l0)
		datalist.append(dtl)
		
		dtl=[]
		s10=soup.find_all(class_='weather-10day')
		head=soup.find_all(class_='weather-10day__head')[0]
		headp=[i.get_text() for i in head.find_all("p")]
		for i in range(len(headp)):
			if("（" in headp[i]):
				headp[i]=headp[i][:headp[i].find("（")]
		headp.insert(1,"icon")
		headp[0]="日付"
		dtl.append(headp)
		for s1 in s10:
			timedata=s1.find_all(class_='weather-10day__item')
			for t0 in timedata:
				l0=[]
				dayd=t0.find(class_='weather-10day__day').get_text()
				dayd=dayd[:dayd.find("(")]
				dayd=stringDate(dayd)
				l0.append(dayd)
				img=t0.find_all("img")[0]['src']
				if("dummy" in img):
					img=t0.find_all("img")[0]['data-original']
				if(not("https:" in img)):
					img="https:"+img
				l0.append(img)
				idata=self.get_img(img)
				l0.append(self.img_equals(idata))
				l0.append(t0.find(class_='weather-10day__h txt-h').get_text().replace("℃","").replace("%","").replace("mm/h","").replace("m/s",""))
				l0.append(t0.find(class_='weather-10day__l txt-l').get_text().replace("℃","").replace("%","").replace("mm/h","").replace("m/s",""))
				l0.append(t0.find(class_='weather-10day__r').get_text().replace("℃","").replace("%","").replace("mm/h","").replace("m/s",""))
				dtl.append(l0)
		datalist.append(dtl)
		
		datalist.append(self.location)
		return datalist
			
	def get_icon(self):
		url="https://weathernews.jp/s/topics/img/wxicon/"
		html=requests.get(url).content
		soup=BeautifulSoup(html, 'html.parser')
		s0=soup.find_all(class_='card')
		list=[]
		for s1 in s0:
			img="https://smtgvs.weathernews.jp/onebox/img/wxicon"+(s1.find("img")['src'])[1:]
			text=s1.find_all("dt")[0].get_text()
			idata=self.get_img(img)
			list.append([idata,text])
		return list
	
	def get_img(self,path):
		try:
			with urllib.request.urlopen(path) as web_file:
				return web_file.read()
		except urllib.error.URLError as e:
			return 0
	
	def img_equals(self,idata):
		for i in self.icon_data:
			if(i[0]==idata):
				return i[1]
		return "-----"
	
	def json_save(self):
		type_name=["2days","10days"]
		data_location=self.all[2]
		cldata=cl.OrderedDict()
		cllocation=cl.OrderedDict()
		cllocation["name"]=data_location[0]
		cllocation["名前"]=data_location[1]
		cllocation["所在地"]=data_location[2]
		cllocation["geocoding"]=data_location[3]
		cldata["場所"]=cllocation
		for n in range(2):
			cltype=cl.OrderedDict()
			data_f1=self.all[n]
			name_list1=data_f1[0]
			for i in range(len(data_f1)):
				if(i!=0):
					cld=cl.OrderedDict()
					str=""
					for j in range(len(name_list1)):
						cld[name_list1[j]]=data_f1[i][j]
						if(j==0 or (j==1 and n==0)):
							str+=data_f1[i][j]
					cltype[str]=cld
			cldata[type_name[n]]=cltype
		f=open("forecast/"+self.location[0]+".json",'w',encoding="utf-8")
		json.dump(cldata,f,indent=4,ensure_ascii=False)
		f.close()