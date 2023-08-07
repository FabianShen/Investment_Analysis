* Change path to raw data
global path_to_data = "C:\Users\Fabian\Desktop\3080\HW2"

* CD raw data folder
cd $path_to_data

*** Import Data ***
*--------------------Stock Return on Equity--------------------*
import delimited FI_T5.csv, encoding(UTF-8) clear
* Rename variables *
rename stkcd stock_code
rename f050504c roe_ttm

save stock_roe, replace
*----------------------Stock Balance Sheet---------------------*
import delimited FS_Combas, encoding(UTF-8) clear
* Rename variables*
rename a001000000 asset
rename a002000000 lblty
rename stkcd stock_code
* Select valuable data
keep if typrep == "A"
* Calculate bookvalue
gen bookval = asset - lblty
* Generate date
gen date = date(accper,"YMD")
gen date_yq = qofd(date)
format date_yq %10.3f
* Drop Dec. since the Jan. report is same as Dec.
gen date_m = month(date)
drop if date_m == 1
* Generate year
gen date_y = year(date)
* Generate month
expand 3
sort stock_code accper
bys stock_code date_yq date_m: gen q = _n // then we have the 3 order month in one quarter
replace q = date_m + q - 1 // current quarter balance sheet is to calculate the next month PB ratio
replace q = q - 12 if date_m == 12
replace q = 12 if q == 0
replace date_y = date_y + 1 if date_m == 12 & q != 12

gen date_ym = ym(date_y,q)
drop q date_y date_m date date_yq shortname_en typrep accper
save stock_bkval, replace

*---------------------Stock Market Value---------------------*
import delimited TRD_Mnth, encoding(UTF-8) clear
* Rename variables *
rename stkcd stock_code
rename msmvttl market_val
rename mretnd stock_ret
* Generate monthly dates
gen date_ym = monthly(trdmnt, "YM")
format date_ym %tm

save stock_mkt, replace

*----------------------Stock Volatility----------------------*
import delimited STK_MKT_Stkbtal, encoding(UTF-8) clear
* Rename
rename symbol stock_code
* Keep 2010Q4 data
keep if tradingdate == "2010-12-31"
gen vola_q = volatility ^ (1/4) // mordify volatily to quarterly
* Generate month
gen date = date(tradingdate,"YMD")
gen date_yq = qofd(date)
drop date tradingdate volatility

save stock_vola, replace

*-------------------------Data Merge-------------------------*
use stock_bkval, clear
merge m:1 stock_code date_ym using stock_mkt
keep if _merge == 3
drop _merge
gen stock_pb = market_val*1000/bookval
save stock_pb, replace
sum stock_pb

*------------------------Question (1)------------------------*
use stock_roe, clear
keep if typrep == "A" & accper == "2010-12-31"
drop if roe_ttm == .
* Generate date
gen date = date(accper,"YMD")
gen date_yq = qofd(date)
format date_yq %10.3f
drop date shortname_en accper typrep
save pro_roe, replace
use pro_roe,clear
* Merge volatility and ROE data
use stock_pb, clear
gen date_yq = qofd(dofm(date_ym))
keep if date_yq == 203 // date_yq == 203 means 2010Q4
*keep if trdmnt == "2010-12"
merge m:1 stock_code date_yq using stock_vola
keep if _merge == 3
drop _merge
merge m:1 stock_code date_yq using pro_roe
keep if _merge == 3
drop _merge
bys stock_code date_yq: egen ew_stock_pb = mean(stock_pb)
* Take overview of PB ratio
sum stock_pb vola_q roe_ttm
save stock_reg, replace
* We consider in two cases
*(1) Keep the PB <= 0 since the market value overall firms
use stock_reg, replace
reg stock_pb vola_q roe_ttm
duplicates drop stock_code ew_stock_pb, force
reg ew_stock_pb vola_q roe_ttm

*(2) Drop PB <= 0 since firm is under ST and need to revalue
*(i) Don't mortify PB
use stock_reg, clear
drop if ew_stock_pb <= 0
duplicates drop stock_code ew_stock_pb, force
reg ew_stock_pb vola_q roe_ttm
use stock_reg, clear
drop if stock_pb <= 0
reg stock_pb vola_q roe_ttm
*(ii) Mortify extreme point i.e., PB>100
use stock_reg, clear
drop if ew_stock_pb > 100 | ew_stock_pb <= 0
duplicates drop stock_code ew_stock_pb, force
reg ew_stock_pb vola_q roe_ttm
use stock_reg, clear
drop if stock_pb > 100 | stock_pb <= 0
reg stock_pb vola_q roe_ttm

*(3) Log-Log regression
*(i) Three month crosssectional regression
use stock_reg, clear
gen log_pb = log(stock_pb)
gen log_roe = log(roe_ttm)
gen log_vola = log(vola)
reg log_pb log_roe log_vola
*(ii) equal weighted for three month
gen l_ew_pb = log(ew_stock_pb)
reg l_ew_pb log_roe log_vola

*-------------------------Question (2)------------------------*
use stock_pb, clear
drop if stock_pb ==.
gen stock_id = group(stock_code)
xtset stock_code date_ym
gen lag_pb = l.stock_pb
drop if lag_pb == .
* Generate market P/B quantiles
bys date_ym: egen pb_decile = xtile(lag_pb), nq(10)
* Derive equal-weighted returns
bys date_ym pb_decile: egen ew_rt = mean(stock_ret)
keep if date_ym > 599 // keep date form 2010m1 to 2022m12

* Claim the data set as panel (on stock id and date)*

duplicates drop date_ym pb_decile, force
keep pb_decile date_ym ew_rt
format date_ym %tm
gen stock_id = group(pb_decile)
xtset pb_decile date_ym
** Time-series for disparity
xtline ew_rt if pb_decile == 1|pb_decile == 10, overlay
graph save disparity, replace
** Time-series for overview
xtline ew_rt, overlay
graph save overview, replace

** Detail time series
forvalue k = 1/13{
	xtline ew_rt if date_ym <=600+12*`k' & date_ym >600+12*(`k'-1), overlay
	graph save `k',replace
}

* Calculate cummulative return
sort pb_decile date_ym
gen r = 1 + ew_rt
gen ax = r
by pb_decile: gen z = _n
by pb_decile: replace ax = ax[_n-1]*r if z>1
replace ax = ax - 1
xtline ax, overlay
