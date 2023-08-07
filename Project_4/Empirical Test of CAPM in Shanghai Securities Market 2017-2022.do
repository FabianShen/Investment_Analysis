* Change path to raw data
global path_to_data = "C:\Users\Fabian\Desktop\3080\HW4"

* CD raw data folder
cd $path_to_data

*** Import Data ***
*--------------------Risk free return--------------------*
import delimited TRD_Nrrate.csv, encoding(UTF-8) clear

gen date_yw = wofd(date(clsdt,"YMD"))
rename nrrwkdt rf
keep rf date_yw

save mkt_rf, replace

*--------------------Individual return--------------------*
import delimited TRD_Week.csv, encoding(UTF-8) clear
save stock_wk, replace
import delimited TRD_Week1.csv, encoding(UTF-8) clear
save stock_wk1,replace
use stock_wk, replace
append using stock_wk1
* Rename variable and time-data
rename stkcd stock_code
rename wretnd stock_ret
gen date_yw = weekly(trdwnt,"YW")
drop if date_yw ==.

save stock_wk, replace

*--------------------Market return--------------------*
import delimited TRD_Weekcm.csv, encoding(UTF-8) clear
keep if markettype == 5
gen date_yw = weekly(trdwnt,"YW")
rename cwretmdeq stock_rm
keep stock_rm date_yw

save stock_rm, replace


*** Merge Data ***
use stock_wk, clear
merge m:n date_yw using mkt_rf
keep if _merge == 3
drop _merge
merge m:n date_yw using stock_rm
keep if _merge == 3
drop _merge
egen date_decile = xtile(date_yw),nq(3)
save stock_merged, replace

*** Regression on individual beta ***
use stock_merged, clear
asreg stock_ret stock_rm if date_decile == 1, by(stock_code)
drop _Nobs
bys stock_code: egen beta_i = mean(_b_stock_rm)
bys stock_code: egen alpha_i = mean(_b_cons)
bys stock_code: egen R2_i = mean(_R2)
bys stock_code: egen R_adj_i = mean(_adjR2)
drop if beta_i == . // Drop all stocks has not all time series
drop _b_stock_rm _b_cons _R2 _adjR2
save stock_process_1, replace

*** Regression on portfolio beta ***
use stock_process_1, clear
gen rm_rf = stock_rm - rf
* Equal weighted
egen stock_decile = xtile(beta_i), nq(10)
bys stock_decile date_yw: egen ew_rp = mean(stock_ret)
gen ew_rp_rf = ew_rp - rf
asreg ew_rp_rf rm_rf if date_decile == 2, by(stock_decile)

