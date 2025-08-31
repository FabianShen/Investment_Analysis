*** Import Data ***
*--------------------Earning per Share--------------------*
import delimited FI_T9.csv, encoding(UTF-8) clear

keep if typrep == "A"
rename stkcd stock_code
rename f090101b eps
gen date = date(accper,"YMD")
format date %td
gen year = year(date)
gen month = month(date)
keep if month == 6 | month == 12
gen hy = 1
replace hy = 2 if month == 12
gen date_yh = yh(year,hy)
format date_yh %th

egen stock_id = group(stock_code)
xtset stock_id date_yh
gen leps = l.eps
bys stock_code year: replace eps = eps - leps if hy == 2
drop month year date typrep shortname_en accper
save eps_1, replace

* Derive unexpected earnings
use eps_1, clear
xtset stock_id date_yh
gen l2eps = l2.eps
bys stock_code: gen ue = eps - l2eps

* Derive SUE
xtset stock_id date_yh
gen lue = l.ue
gen l2ue = l2.ue
gen l3ue = l3.ue
egen sdue = rowsd(ue lue l2ue l3ue)
gen sue = ue/sdue

* Generating deciles
bys date_yh: egen sue_decile = xtile(sue),nq(10)
save stock_sue, replace

*--------------------Earning per Share--------------------*
import delimited IAR_Rept.csv, encoding(UTF-8) clear
rename stkcd stock_code
gen date = date(accper,"YMD")
format date %td
gen year = year(date)
gen month = month(date)
keep if month == 6 | month == 12
gen hy = 1
replace hy = 2 if month == 12
gen date_yh = yh(year,hy)
format date_yh %th
merge 1:1 date_yh stock_code using stock_sue
keep if _merge == 3
drop _merge
drop if strmatch(stknme_en,"*ST*")
drop if strmatch(stknme_en,"*PT*")

save stock_p1, replace

*--------------------Individual return--------------------*
cd "C:\Users\Fabian\Desktop\3080\HW5\daily_2013"
import delimited TRD_Dalyr.csv, encoding(UTF-8) clear
save data_1, replace
import delimited TRD_Dalyr1.csv, encoding(UTF-8) clear
save data_2, replace
import delimited TRD_Dalyr2.csv, encoding(UTF-8) clear
save data_3, replace
import delimited TRD_Dalyr3.csv, encoding(UTF-8) clear
save data_4, replace
use data_1 ,clear
append using data_2 data_3 data_4
save C:\Users\Fabian\Desktop\3080\HW5\daily_2013,replace

cd "C:\Users\Fabian\Desktop\3080\HW5\daily_2018"
import delimited TRD_Dalyr.csv, encoding(UTF-8) clear
save data_1, replace
import delimited TRD_Dalyr1.csv, encoding(UTF-8) clear
save data_2, replace
import delimited TRD_Dalyr2.csv, encoding(UTF-8) clear
save data_3, replace
import delimited TRD_Dalyr3.csv, encoding(UTF-8) clear
save data_4, replace
import delimited TRD_Dalyr4.csv, encoding(UTF-8) clear
save data_5, replace
import delimited TRD_Dalyr5.csv, encoding(UTF-8) clear
save data_6, replace
use data_1 ,clear
append using data_2 data_3 data_4 data_5 data_6
save C:\Users\Fabian\Desktop\3080\HW5\daily_2018,replace
cd $path_to_data
use daily_2013, clear
append using daily_2018

* Keep only mainboard stocks
rename stkcd stock_code
tostring stock_code, replace
replace stock_code = substr("000000",1,6-length(stock_code)) + stock_code
keep if substr(stock_code,1,2) == "60" | substr(stock_code,1,2) == "00" 
save stock_ret, replace
*--------------------Individual return--------------------*
use stock_p1, clear
drop if date_yh < 111
save stock_pro, replace
import delimited TRD_Cndalym.csv, encoding(UTF-8) clear
keep if markettype == 5
save stock_mkt, replace

*** Merge
use stock_ret, clear
merge m:1 trddt using stock_mkt
drop _merge
*** Derive daily abnormal returns
rename dretnd stock_ret
rename cdretmdeq mkt_ret
sort stock_code trddt
egen stock_id = group(stock_code)
gen date = date(trddt,"YMD")
format date %td
xtset stock_id date
gen ars = stock_ret - mkt_ret

* Merge stock return with eps

destring stock_code,replace force
drop stock_id markettype 
merge m:n stock_code date using stock_pro
drop if _merge == 2

save stock_p2, replace

*--------------------CARs return--------------------*
use stock_p1, clear
drop if sue ==.
rename accper trddt
drop stknme_en reptyp year month hy lep l2eps lue l2ue l3ue sdue
gen date_e = date(annodt,"YMD")
format date_e %td
save stock_event, replace

use stock_ret, clear
destring stock_code, replace force
gen date = date(trddt,"YMD")
format date %td
drop trddt
rename dretnd stock_ret
save stock_returns, replace

use stock_mkt, clear
gen date = date(trddt,"YMD")
format date %td
drop trddt
rename cdretmdeq mkt_ret
save market_return, replace

*-------------------------------------*
use stock_p2, clear
sort stock_code date
by stock_code : gen date_num = _n
by stock_code : gen target = date_num if sue != .
egen td = min(target), by(stock_code)
drop target
gen dif = date_num - td
by stock_code: gen event = 1 if dif >=-120 & dif <= 120
egen count_event = count(event), by(stock_code)
replace event = 0 if event ==.
by stock_code: gen car = sum(ar) if event == 1
save stock_car, replace
					*-------------second---------------*
use stock_p2, clear
sort stock_code date
by stock_code : gen date_num = _n
by stock_code : gen target = date_num if sue != .
egen td = max(target), by(stock_code)
drop target
gen dif = date_num - td
by stock_code: gen event = 1 if dif >=-120 & dif <= 120
egen count_event = count(event), by(stock_code)
replace event = 0 if event ==.
by stock_code: gen car = sum(ar) if event == 1
save stock_car_1, replace
					*-------------third---------------*
use stock_p2, clear
sort stock_code date
by stock_code : gen date_num = _n
by stock_code : gen target = date_num if sue != .
egen td = max(target), by(stock_code)
replace target =. if target == td
drop td
egen td = max(target), by(stock_code)
gen dif = date_num - td
by stock_code: gen event = 1 if dif >=-120 & dif <= 120
egen count_event = count(event), by(stock_code)
replace event = 0 if event ==.
by stock_code: gen car = sum(ar) if event == 1
save stock_car_2, replace
				*------------Next generation-----------*
				*---------In order to save time difficulty----------*
use stock_p2, clear
sort stock_code date
by stock_code : gen date_num = _n
by stock_code : gen target = date_num if sue != .
egen td = max(target), by(stock_code)
replace target =. if target == td
drop td
egen td = max(target), by(stock_code)
replace target =. if target == td
drop td
egen td = max(target), by(stock_code)
gen dif = date_num - td
by stock_code: gen event = 1 if dif >=-120 & dif <= 120
egen count_event = count(event), by(stock_code)
replace event = 0 if event ==.
by stock_code: gen car = sum(ar) if event == 1
save stock_car_3, replace

use stock_p2, clear
sort stock_code date
by stock_code : gen date_num = _n
by stock_code : gen target = date_num if sue != .
egen td = max(target), by(stock_code)
forvalues i =0/3{
replace target =. if target == td
drop td
egen td = max(target), by(stock_code)
}
gen dif = date_num - td
by stock_code: gen event = 1 if dif >=-120 & dif <= 120
egen count_event = count(event), by(stock_code)
replace event = 0 if event ==.
by stock_code: gen car = sum(ar) if event == 1
save stock_car_4, replace

use stock_p2, clear
sort stock_code date
by stock_code : gen date_num = _n
by stock_code : gen target = date_num if sue != .
egen td = max(target), by(stock_code)
forvalues i =0/4{
replace target =. if target == td
drop td
egen td = max(target), by(stock_code)
}
gen dif = date_num - td
by stock_code: gen event = 1 if dif >=-120 & dif <= 120
egen count_event = count(event), by(stock_code)
replace event = 0 if event ==.
by stock_code: gen car = sum(ar) if event == 1
save stock_car_5, replace

use stock_p2, clear
sort stock_code date
by stock_code : gen date_num = _n
by stock_code : gen target = date_num if sue != .
egen td = max(target), by(stock_code)
forvalues i =0/5{
replace target =. if target == td
drop td
egen td = max(target), by(stock_code)
}
gen dif = date_num - td
by stock_code: gen event = 1 if dif >=-120 & dif <= 120
egen count_event = count(event), by(stock_code)
replace event = 0 if event ==.
by stock_code: gen car = sum(ar) if event == 1
save stock_car_6, replace

use stock_p2, clear
sort stock_code date
by stock_code : gen date_num = _n
by stock_code : gen target = date_num if sue != .
egen td = max(target), by(stock_code)
forvalues i =0/6{
replace target =. if target == td
drop td
egen td = max(target), by(stock_code)
}
gen dif = date_num - td
by stock_code: gen event = 1 if dif >=-120 & dif <= 120
egen count_event = count(event), by(stock_code)
replace event = 0 if event ==.
by stock_code: gen car = sum(ar) if event == 1
save stock_car_7, replace

use stock_p2, clear
sort stock_code date
by stock_code : gen date_num = _n
by stock_code : gen target = date_num if sue != .
egen td = max(target), by(stock_code)
forvalues i =0/7{
replace target =. if target == td
drop td
egen td = max(target), by(stock_code)
}
gen dif = date_num - td
by stock_code: gen event = 1 if dif >=-120 & dif <= 120
egen count_event = count(event), by(stock_code)
replace event = 0 if event ==.
by stock_code: gen car = sum(ar) if event == 1
save stock_car_8, replace

*--------------------------Transform--------------------------*
use stock_car, clear
sort stock_code date
drop if car ==.
drop stknme_en reptyp year month hy date_yh stock_id leps l2eps lue l2ue l3ue sdue
by stock_code: gen portfolio = sue_decile if dif == 0
by stock_code: egen e_portfolio = mean(portfolio)
save stock_car2, replace

use stock_car_1, clear
sort stock_code date
drop if car ==.
drop stknme_en reptyp year month hy date_yh stock_id leps l2eps lue l2ue l3ue sdue
by stock_code: gen portfolio = sue_decile if dif == 0
by stock_code: egen e_portfolio = mean(portfolio)
save stock_car3, replace

use stock_car_2, clear
sort stock_code date
drop if car ==.
drop stknme_en reptyp year month hy date_yh stock_id leps l2eps lue l2ue l3ue sdue
by stock_code: gen portfolio = sue_decile if dif == 0
by stock_code: egen e_portfolio = mean(portfolio)
save stock_car4, replace

use stock_car_3, clear
sort stock_code date
drop if car ==.
drop stknme_en reptyp year month hy date_yh stock_id leps l2eps lue l2ue l3ue sdue
by stock_code: gen portfolio = sue_decile if dif == 0
by stock_code: egen e_portfolio = mean(portfolio)
save stock_car5, replace

use stock_car_4, clear
sort stock_code date
drop if car ==.
drop stknme_en reptyp year month hy date_yh stock_id leps l2eps lue l2ue l3ue sdue
by stock_code: gen portfolio = sue_decile if dif == 0
by stock_code: egen e_portfolio = mean(portfolio)
save stock_car6, replace

use stock_car_5, clear
sort stock_code date
drop if car ==.
drop stknme_en reptyp year month hy date_yh stock_id leps l2eps lue l2ue l3ue sdue
by stock_code: gen portfolio = sue_decile if dif == 0
by stock_code: egen e_portfolio = mean(portfolio)
save stock_car7, replace

use stock_car_6, clear
sort stock_code date
drop if car ==.
drop stknme_en reptyp year month hy date_yh stock_id leps l2eps lue l2ue l3ue sdue
by stock_code: gen portfolio = sue_decile if dif == 0
by stock_code: egen e_portfolio = mean(portfolio)
save stock_car8, replace

use stock_car_7, clear
sort stock_code date
drop if car ==.
drop stknme_en reptyp year month hy date_yh stock_id leps l2eps lue l2ue l3ue sdue
by stock_code: gen portfolio = sue_decile if dif == 0
by stock_code: egen e_portfolio = mean(portfolio)
save stock_car9, replace

use stock_car_8, clear
sort stock_code date
drop if car ==.
drop stknme_en reptyp year month hy date_yh stock_id leps l2eps lue l2ue l3ue sdue
by stock_code: gen portfolio = sue_decile if dif == 0
by stock_code: egen e_portfolio = mean(portfolio)
save stock_car10, replace

use stock_car3, clear
append using stock_car4 stock_car5 stock_car6 stock_car7 stock_car8 stock_car9 stock_car10
keep e_portfolio dif car
sort e_portfolio dif
bys e_portfolio dif: egen ew_car = mean(car)
drop car
duplicates drop e_portfolio dif, force
twoway (line ew_car dif if e_portfolio == 1) ///
(line  ew_car dif if e_portfolio == 2) ///
(line  ew_car dif if e_portfolio == 3) ///
(line  ew_car dif if e_portfolio == 4) ///
(line  ew_car dif if e_portfolio == 5) ///
(line  ew_car dif if e_portfolio == 6) ///
(line  ew_car dif if e_portfolio == 7) ///
(line  ew_car dif if e_portfolio == 8) ///
(line  ew_car dif if e_portfolio == 9) ///
(line  ew_car dif if e_portfolio == 10), ///
legend( ////
label(1 "SUE-1") label(2 "SUE-2") label(3 "SUE-3") label(4 "SUE-4") ///
label(5 "SUE-5") label(6 "SUE-6") label(7 "SUE-7") label(8 "SUE-8") ///
label(9 "SUE-9") label(10 "SUE-10")) ///
xtitle(date) ytitle(car) xline(0)
