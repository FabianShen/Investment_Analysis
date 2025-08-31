*** Import Data ***
*--------------------Risk free return--------------------*
import delimited TRD_Nrrate.csv, encoding(UTF-8) clear

gen date_yw = wofd(date(clsdt,"YMD"))
rename nrrwkdt rf
replace rf = rf/100
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

*** TS-Regression on individual beta ***
use stock_merged, clear
xtset stock_code date_yw
asreg stock_ret stock_rm if date_decile == 1, by(stock_code)
drop _Nobs
bys stock_code: egen beta_i = mean(_b_stock_rm)
bys stock_code: egen alpha_i = mean(_b_cons)
bys stock_code: egen R2_i = mean(_R2)
bys stock_code: egen R_adj_i = mean(_adjR2)
drop if beta_i == . // Drop all stocks has not all time series
drop _b_stock_rm _b_cons _R2 _adjR2
save stock_process_1, replace
reg stock_ret stock_rm if date_decile == 1 & stock_code == 1
reg stock_ret stock_rm if date_decile == 1 & stock_code == 5
reg stock_ret stock_rm if date_decile == 1 & stock_code == 6
reg stock_ret stock_rm if date_decile == 1 & stock_code == 7
reg stock_ret stock_rm if date_decile == 1 & stock_code == 9
reg stock_ret stock_rm if date_decile == 1 & stock_code == 11
reg stock_ret stock_rm if date_decile == 1 & stock_code == 16
reg stock_ret stock_rm if date_decile == 1 & stock_code == 17
reg stock_ret stock_rm if date_decile == 1 & stock_code == 26
reg stock_ret stock_rm if date_decile == 1 & stock_code == 27


*** TS-Regression on portfolio beta ***
use stock_process_1, clear
gen rm_rf = stock_rm - rf
* Equal weighted
egen stock_decile = xtile(beta_i), nq(10)
bys stock_decile date_yw: egen ew_rp = mean(stock_ret)
gen ew_rp_rf = ew_rp - rf
asreg ew_rp_rf rm_rf if date_decile == 2, by(stock_decile) fit
drop _Nobs
bys stock_decile: egen r = mean(_residuals)
bys stock_decile: egen beta_p = mean(_b_rm_rf)
bys stock_decile: egen alpha_p = mean(_b_cons)
bys stock_decile: egen R2_p = mean(_R2)
bys stock_decile: egen R_adj_p = mean(_adjR2)
drop _b_rm_rf _b_cons _R2 _adjR2 _residuals _fitted
save stock_process_2, replace

*** TS-Regression export ***
use stock_process_1, clear
gen rm_rf = stock_rm - rf
* Equal weighted
egen stock_decile = xtile(beta_i), nq(10)
bys stock_decile date_yw: egen ew_rp = mean(stock_ret)
gen ew_rp_rf = ew_rp - rf
duplicates drop ew_rp_rf date_yw, force
levelsof stock_decile, local(cl)
foreach lv of local cl {
    reg ew_rp_rf rm_rf if stock_decile == `lv' & date_decile == 2
    est store cl_`lv'
}

outreg2 [cl_*] using c3.doc, replace

*** Cross-sectional regression ***
use stock_process_2, clear
bys beta_p: egen E_rp_rf = mean(stock_ret) if date_decile == 3
replace E_rp_rf = E_rp_rf - rf
duplicates drop E_rp_rf beta_p, force
drop if E_rp_rf ==.
reg E_rp_rf beta_p
predict yhat
twoway(scatter E_rp_rf beta_p if date_decile == 3)(line yhat beta_p)
gen beta_2 = beta_p^2
gen E_rp = E_rp_rf + rf
reg E_rp beta_p beta_2 
