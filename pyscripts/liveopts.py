import urllib2
from bs4 import BeautifulSoup
import datetime
import pandas
import csv
import os
import re
import logging
import OptionGreeks as og

logging.basicConfig(format='%(levelname)s %(asctime)s:%(message)s', level=logging.DEBUG)

get_text = lambda x: x.getText()

option_site = 'http://www.nseindia.com/live_market/dynaContent/live_watch/option_chain/optionKeys.jsp?symbol=&lt;symbol&gt;&date=&lt;expiry&gt;&instrument=&lt;imnt_type&gt;'

opt_imnt_type = {'stock': 'OPTSTK', 'index': 'OPTIDX'}


def convert_to_date(dt):
    try:
        return datetime.datetime.strptime(dt[:2] + dt[2:5].title() + dt[5:], "%d%b%Y")
    except ValueError:
        return None


def convert_to_float(num):
    try:
        return float(num.replace(',', ''))
    except ValueError:
        return None


def get_soup(site):
    """get the html source for a web site"""
    try:
        #logging.debug("Getting data from:" + site)

        hdr = {'User-Agent': 'Web-Scraping',
               'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
               'Accept-Charset': 'ISO-8859-1,utf-8;q=0.7,*;q=0.3',
               'Accept-Encoding': 'none',
               'Accept-Language': 'en-US,en;q=0.8',
               'Connection': 'keep-alive'}

        req = urllib2.Request(site, headers=hdr)

        page = urllib2.urlopen(req).read()
        return BeautifulSoup(page, "html.parser")
    except:
        logging.debug("Check the site: " + str(site))
        raise


def get_expiries(symbol):
    """Get option expiries"""
    soup = get_soup(
        option_site.replace("&lt;symbol&gt;", symbol).replace("&lt;expiry&gt;", "-").replace("&lt;imnt_type&gt;", "-"))
    expiries = []
    for i in soup.findAll('select')[1].findChildren('option'):
        exp = convert_to_date(i.getText())
        if exp:
            expiries.append(exp)
            #logging.debug("Expiry " + str(i) + " is : " + str(exp) )

    return expiries


def get_option_data(symbol, lots, sd, isIndex=True):
    expiries = get_expiries(symbol)
    for expiry in expiries:
        #logging.debug("Expiry is " + expiry.strftime("%d%b%Y").upper())
        imnt_type = opt_imnt_type['index'] if isIndex else opt_imnt_type['stock']
        imnt_type = '-'
        soup = get_soup(option_site.replace("&lt;symbol&gt;", symbol).replace("&lt;expiry&gt;", expiry.strftime(
            "%d%b%Y").upper()).replace("&lt;imnt_type&gt;", imnt_type))
        spot_prc_string = soup.findAll('table')[0].findChildren('td')[1].findChildren('span')[0].getText()
        if (len(spot_prc_string.split(':')) != 2 ) :
            logging.debug("THIS ONE HAS ISSUE PARSING=> " + spot_prc_string)
            continue;
        y,z = spot_prc_string.split(':')
        x,spot_price = z.split()
        trade_date = datetime.datetime.strptime(re.findall(r'\w{3}\s\d{2},\s\d{4}',
                                                           soup.findAll('table')[0].findChildren('td')[1].findChildren(
                                                               'span')[1].getText())[0], '%b %d, %Y')

        table = soup.findAll('table')[2]
        rows = table.findAll('tr')
        totals = map(convert_to_float, map(get_text, rows[len(rows)-1].findAll('td')))
        spcr = 0
        opcr = 0
        delta = 0
        chgperc = 0
        totchgperc = 0
        totalotm = 0
        totalotmneg = 0
        
        for row in rows[2:len(rows) - 1]:
            opts = map(convert_to_float, map(get_text, row.findAll('td')))
            #print opts
            if (opts[17] and opts[11] < float(spot_price))  :
                #print '{0}, {1}, {2}, {3}, {4}, {5}'.format(symbol, spot_price, float(lots)*float(opts[17]), expiry, opts[11],opts[17])
                if (opts[21] and opts[1]) :
                    opcr = opts[21] / opts[1]
                if (opts[18]):
                    opt = og.Option(s=spot_price, k=opts[11], eval_date=trade_date, exp_date=expiry, rf=0.01, vol=opts[18]/100, right='P')
                    price, delta, theta, gamma = opt.get_all()
                    #print '{0}, {1}, {2}, {3}, {4}, {5},{6},{7:.2f}'.format(spot_price, opts[11],trade_date,expiry, 0.01, opts[18]/100,'P',delta)
                    if(opts[16]):
                        chgperc = (opts[16] / opts[17] ) * 100
                        totchgperc += chgperc
                        totalotm += 1 
                        if(opts[16] < 0):
                            totalotmneg += 1
                            
                #if(float(lots)*float(opts[17]) > 10000):
                otmput = [trade_date,symbol, float(spot_price), float(lots)*float(opts[17]), expiry, opts[11],opts[17], opts[18],sd,chgperc,lots,spcr,opcr,delta]
                #print otmput
                tup.append(tuple(otmput))

        if (totals[7] and totals[1]) :
            #print 'OI on Call Side', totals[1]
            #print 'OI on Put Side', totals[7]
            spcr = totals[7] / totals[1]
            dire = 0
            negparts = 0
            if (totalotm):
                dire = totchgperc /  totalotm
                negparts = totalotmneg / totalotm
            oi_put = [symbol,expiry.strftime('%Y-%m-%d'),totals[1],totals[7],totals[7]/totals[1], dire, totalotmneg, totalotm,negparts]
            oi_tup.append(tuple(oi_put))
            print oi_put

if __name__ == '__main__':
    global tup
    global  oi_tup
    tup = []
    oi_tup = []
    global trade_date 
    trade_date = datetime.datetime.now() 
    with open('../data/refdata.csv', 'rb') as csvfile:
        csvreader = csv.reader(csvfile, delimiter=',')
        i = 0;
        for row in csvreader:
            #symbol, dot, exch = row[0].partition('.')
            #print symbol
            i = i +1
            if (i > 10):
                symbol = row[0].strip()
                lots = row[1]
                sd = row[3]
                get_option_data(symbol, lots, sd,isIndex=False)
    headers = ['TradeDt','Symbol', 'SpotPrice', 'Profit', 'Expiry', 'Strike', 'Premium', 'IV','SD','chgperc','lots','sym_pcr','opt_pcr','delta']
    df = pandas.DataFrame(tup, columns=headers)
    pandas.set_option('display.width', 150)
    print df
    df.to_csv('../data/liveopts.csv')
    oi_df = pandas.DataFrame(oi_tup, columns=['Symbol', 'Expiry','Call OI', 'Put OI', 'PCR', 'DIR','NEG','TOT','NEGPART']) 
    print oi_df
    oi_df.to_csv('../data/oi_opts.csv')

