*** Import Data ***
*--------------------Stock Return & End Price--------------------*
import delimited TRD_Mnth.csv, encoding(UTF-8) clear
rename stkcd stock_code
rename mclsprc end_p
rename mretnd stock_ret

* Set time-serie panel
gen date_ym = monthly(trdmnt,"YM")
egen stock_id = group(stock_code)
sort stock_code date_ym
xtset stock_id date_ym
* Generate portfolio based on last return
gen l_ret = l.stock_ret
gen l_end_p = l.end_p
drop if l_ret ==.
bys date_ym: egen ret_decile = xtile(l_ret), nq(10)
bys date_ym ret_decile: egen ew_rt = mean(stock_ret)
save stock_ret, replace

*--------------------Retuen on Equity--------------------*
import delimited FI_T5.csv, encoding(UTF-8) clear
keep if typrep == "A"
rename stkcd stock_code
rename f050504c stock_roe
gen date = date(accper,"YMD")
gen date_yq = qofd(date)
format date_yq %tq
drop date shortname_en accper typrep

save stock_roe, replace

*--------------------Generate Quarter return--------------------*
use stock_ret,clear
drop stock_id ret_decile ew_rt 
format date_ym %tm
gen date_yq = qofd(date(trdmnt,"YM"))
format date_yq %tq
sort stock_code date_yq date_ym
* Generate quarterly return based on closing price
gen earn =  end_p - l_end_p
bys stock_code date_yq: egen earn_q = sum(earn)
bys stock_code date_yq: gen n = _n
gen ret_q_p = earn_q / l_end_p if n == 1

* Generate quarterly return based on monthly return
gen log_ret = log(1+stock_ret)
bys stock_code date_yq: egen ret_q_r = sum(log_ret)
replace ret_q_r = exp(ret_q_r) -1 

* Clean the panel data
drop if ret_q_p ==.
keep stock_code date_yq ret_q_r ret_q_p l_ret

save stock_ret_q, replace
*--------------------Question (1)--------------------*
use stock_ret,clear
* Real return from each portfolio
bys ret_decile: egen mean_ew_rt = mean(ew_rt)
egen m_rt = mean(stock_ret)
local m_rt = m_rt
graph bar ew_rt, over(ret_decile) yline(`m_rt', lp(dash) lc(blue*0.5))

* Choosen return based on last month
bys ret_decile: egen ew_lrt = mean(l_ret)
egen m_lrt = mean(l_ret)
local m_lrt = m_lrt
graph bar ew_lrt, over(ret_decile) yline(`m_lrt', lp(dash) lc(blue*0.5))

* Median Statistics
use stock_ret, clear
bys date_ym ret_decile: egen med_lrt = pctile(l_ret), p(50)
gen med_1 = med_lrt if ret_decile == 1
gen med_10 = med_lrt if ret_decile == 10
keep date_ym med_1 med_10
bys date_ym: egen x = mean(med_10)
bys date_ym: replace med_10 = x
duplicates drop  date_ym med_1 med_10, force
drop if med_1 ==.
drop x
gen ret_ratio = med_1 / med_10
graph twoway (line ret_ratio date_ym,yaxis(1)) (line med_10 med_1 date_ym,yaxis(2) ),xlabel(624(20)755, format(%tm))

* Calculate cummulative return
use stock_ret, clear
duplicates drop  date_ym ret_decile, force
xtset ret_decile date_ym
sort ret_decile date_ym
gen r = 1 + ew_rt
gen ax = r
by ret_decile: gen z = _n
by ret_decile: replace ax = ax[_n-1]*r if z>1
replace ax = ax - 1
xtline ax, overlay xlabel(624(20)755, format(%tm))


*--------------------Question (2)--------------------*

use stock_roe, clear
* Set time-series panel
egen stock_id = group(stock_code)
xtset stock_id date_yq
* Generate lagged roe
gen l_roe =l.stock_roe
drop if l_roe == .

* Merge data
merge 1:1 stock_code date_yq using stock_ret_q
keep if _merge == 3
drop _merge

* Generate portfolio based on last roe
bys date_yq: egen roe_decile = xtile(l_roe), nq(10)
* Based on closing price
bys date_yq roe_decile: egen ew_rt = mean(ret_q_p)
bys roe_decile: egen mean_ew_rt = mean(ew_rt)
egen m_roe = mean(l_ret)
local m_roe = m_roe
graph bar ew_rt, over(roe_decile) yline(`m_roe', lp(dash) lc(blue*0.5))
save roe_ret, replace

* Median Statistics
use roe_ret, clear
bys date_yq roe_decile: egen med_lroe = pctile(l_roe), p(50)
gen med_1 = med_lroe if roe_decile == 1
gen med_10 = med_lroe if roe_decile == 10
keep date_yq med_1 med_10
bys date_yq: egen x = mean(med_10)
bys date_yq: replace med_10 = x
duplicates drop  date_yq med_1 med_10, force
drop if med_1 ==.
drop x
gen ret_ratio = med_1 / med_10
graph twoway (line ret_ratio date_yq,yaxis(1)) (line med_10 med_1 date_yq,yaxis(2) )

use roe_ret, replace
* Calculate cummulative return
duplicates drop  date_yq roe_decile, force
xtset roe_decile date_yq
sort roe_decile date_yq
gen r = 1 + ew_rt
gen ax = r
by roe_decile: gen z = _n
by roe_decile: replace ax = ax[_n-1]*r if z>1
replace ax = ax - 1
xtline ax, overlay xlabel(208(14)255, format(%tq))

* ANOTHER INTERESTING DISCOVERY *
use roe_ret, replace
drop ew_rt mean_ew_rt
// install asreg for simplify calculating residual
// ssc install asreg
* Calculate redisuals for determine over/under-valued
asreg l_ret l_roe , by(date_yq) fitted
rename _residuals u
bys date_yq: egen u_decile = xtile(u), nq(10)
bys date_yq u_decile: egen ew_rt = mean(ret_q_p)
graph bar ew_rt, over(u_decile)

* Time-series graph
duplicates drop date_yq u_decile, force
xtset u_decile date_yq
gen r = 1 + ew_rt
gen ax = r
sort u_decile date_yq
by u_decile: gen z = _n
by u_decile: replace ax = ax[_n-1]*r if z>1
replace ax = ax - 1
xtline ax, overlay xlabel(208(14)255, format(%tq))
