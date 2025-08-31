* Change path to raw data

*** 1. Stock return, market capitalization ***
* Import individual stock return *
import delimited TRD_Mnth.csv,  encoding(UTF-8)  clear

save raw_stock_return, replace

* Rename variables *
rename mretnd stock_ret
rename stkcd stock_code
rename markettype market
rename msmvttl market_cap

* Generate monthly dates, quarterly dates
gen date_ym = monthly(trdmnt, "YM")
format date_ym %tm

gen date_yq=qofd(dofm(date_ym))
format date_yq %tq

gen date_yy=year(dofm(date_ym))

* Generate log_stock_return
gen log_stock_ret = log(1 + stock_ret)

* Formulate quaterly return
mtoq log_stock_ret, by(stock_code date_ym) s(sum)
gen stock_ret_yq = exp(q_log_stock_ret) - 1

drop trdmnt mretwd log_stock_ret q_log_stock_ret
save processed_stock_return, replace

*** 2. Firm_age ***
import delimited OFDI_ListStkRight.csv,  encoding(UTF-8)  clear

save raw_stock_age, replace

* Rename variables
rename symbol stock_code
rename enterpriseage stock_age

* Generate annually dates
gen date = date(enddate,"YMD")
format date %tdCY-N-D
gen date_yy = year(date)

drop shortname_en enddate date

*save processed_stock_age, replace

expand 4
bys stock_code date_yy: gen q = _n
gen date_yq = yq(date_yy,q)
format date_yq %tq
save processed_stock_age_yq, replace

*** 3. Total Asset ***
import delimited FS_Combas.csv,  encoding(UTF-8)  clear

save raw_stock_total_asset, replace

* Rename variable
rename stkcd stock_code
rename a001000000 total_asset

* choose accounting type
keep if typrep == "A"

* Generate quaterly dates
gen date = date(accper,"YMD")
gen date_yq = qofd(date)
format date_yq %tq

drop typrep accper shortname date

save processed_stock_total_asset, replace

*** 4. R&D Investment ***
import delimited OFDI_FinIndex.csv,  encoding(UTF-8)  clear

save raw_stock_RD

* Rename variables
rename rdspendsum rd_invest
rename symbol stock_code

* Generate annual dates
gen date = date(enddate,"YMD")
format date %tdCY-N-D
gen date_yy = year(date)

* Reform investment
replace rd_invest = 0 if rd_invest == .
gen rd_dum = 0 if rd_invest == 0
replace rd_dum = 1 if rd_dum ==.

* Keep variables
keep stock_code rd_invest date_yy rd_dum

save processed_stock_RD, replace

*** 5. R&D Investment and Total Income***
import delimited FS_Comins.csv,  encoding(UTF-8)  clear

save raw_stock_Inc_RD, replace

* Rename variables
rename b001216000 rd_invest
rename b001000000 total_income
rename stkcd stock_code

* choose accounting type
keep if typrep == "A"

* Generate quarter dates
gen date = date(accper,"YMD")
gen date_yq = qofd(date)
format date_yq %tq

* Reform investment
replace rd_invest = 0 if rd_invest == .
gen rd_dum = 0 if rd_invest == 0
replace rd_dum = 1 if rd_dum ==.

* Keep variables
drop accper typrep shortname_en date

save processed_stock_Inc_RD, replace

*** 6. P/E ratio P/B ***
import delimited FI_T10.csv,  encoding(UTF-8)  clear

save raw_stock_ratio, replace

* Rename variables
rename stkcd stock_code
rename f100102b stock_pe
rename f100401a stock_pb

* Generate quarter dates
gen date = date(accper,"YMD")
gen date_yq = qofd(date)
format date_yq %tq

* Keep varibales
drop accper shortname_en

save processed_stock_ratio, replace

*** Summary ***
*
use processed_stock_return, clear
* Sort markettype
// gen market_re = 1 if market == 1|market == 2|market == 4|market == 8
// replace market_re = 2 if market == 16
// replace market_re = 4 if market == 32
// replace market_re = 8 if market == 64
// label define market_relb 1 "main_board" 2 "GEM_board" 4 "STAR_board" 8 "BeijingA_board"
// label values market_re market_relb

duplicates drop stock_code date_yq, force

* Merge the data with other dataset
merge m:1 stock_code date_yq using processed_stock_age_yq
keep if _merge == 3
drop date_yy q _merge 
merge 1:m stock_code date_yq using processed_stock_Inc_RD
keep if _merge == 3
drop _merge
merge m:1 stock_code date_yq using processed_stock_ratio
keep if _merge == 3
drop _merge date
merge m:n stock_code date_yq using processed_stock_total_asset
keep if _merge == 3
drop _merge
duplicates drop stock_code date_yq, force

* Sort market type
format stock_code %06.0f
tostring stock_code, replace
replace stock_code = substr("000000",1,6-length(stock_code)) + stock_code
gen market_re = 1 if substr(stock_code,1,3)=="300"
replace market_re = 2 if substr(stock_code,1,3)=="002"
replace market_re = 0 if market_re ==.

label define market_relb 0 "main_board" 1 "GEM_board" 2 "SME_board"
label values market_re market_relb

bys market_re: outreg2 using hw1.xls, replace sum(detail) keep(stock_ret stock_ret_yq market_cap stock_age total_income rd_invest stock_pe stock_pb total_asset) eqkeep(N mean sd Var p25 p50 p75) title(Decriptive statistics)
bys market_re: tabstat stock_ret stock_ret_yq market_cap stock_age total_income rd_invest stock_pe stock_pb total_asset, s(n mean med sd p25 p50 p75)
bys market_re: tabstat stock_ret stock_ret_yq market_cap stock_age total_income rd_invest stock_pe stock_pb total_asset,s(n mean median sd p25 p75)
logout, save(mytable) excel replace: bys market_re: tabstat stock_ret_yq market_cap total_income rd_invest stock_pe stock_pb total_asset,s(n mean median sd p25 p75)
logout, save(firm_age) excel replace: tabstat stock_age if date_yq == quarterly("2021q4","YQ"),s(n mean median sd p25 p75) by(market_re)
logout, save(mytable) excel replace: tabstat stock_ret stock_ret_yq market_cap stock_age total_income rd_invest stock_pe stock_pb total_asset,s(n mean median sd p25 p75) by(market_re)
save merged_stock_return, replace

*** Another way to check frim age ***
use processed_stock_return,replace
format stock_code %06.0f
tostring stock_code, replace
replace stock_code = substr("000000",1,6-length(stock_code)) + stock_code
gen market_re = 1 if substr(stock_code,1,3)=="300"
replace market_re = 2 if substr(stock_code,1,3)=="002"
replace market_re = 0 if market_re ==.
duplicates drop market_re stock_code, force
label define market_relb 0 "main_board" 1 "GEM_board" 2 "SME_board"
label values market_re market_relb
keep market_re stock_code
save processed_stock_type, replace

use processed_stock_age, clear
tostring stock_code, replace
replace stock_code = substr("000000",1,6-length(stock_code)) + stock_code
merge m:1 stock_code using processed_stock_type
keep if _merge == 3
drop _merge
tabstat stock_age if date_yy == 2021, s(n mean median sd p25 p75) by(market_re)

***-------------------------------Q2-------------------------------***
*** (1) Generate market panel ***
use merged_stock_return, clear
bys date_yq market_re: egen pe_median = pctile(stock_pe), p(50)
bys market_re: egen pe_median_all = pctile(stock_pe), p(50)
bys date_yq market_re: egen ew_rt = mean(stock_ret_yq)
egen stock_id = group(stock_code)
xtset stock_id date_yq

* Generate lagged pe
gen l_pe_median = l.pe_median
drop if l_pe_median == .
* Generate lagged market_cap
gen l_market_cap = l.market_cap
drop if l_market_cap == .


* Value-weighted mean quarterly return for three market type *
gen ret_cap = stock_ret_yq * l_market_cap
gen rd_cap = rd_invest * l_market_cap
gen inc_cap = total_income * l_market_cap
bys date_yq market_re: egen total_ret_cap = total(ret_cap)
bys date_yq market_re: egen total_rd_cap = total(rd_cap)
bys date_yq market_re: egen total_inc_cap = total(inc_cap)
bys date_yq market_re: egen total_cap = total(l_market_cap)
gen vw_rt = total_ret_cap/total_cap
gen vw_rd = total_rd_cap/total_cap
gen vw_inc = total_inc_cap/total_cap

* Generate reinvestment ratio
gen stock_reinv = rd_invest / total_income
gen stock_grow = stock_reinv * stock_ret_yq

* Calculate portfolio mean returns *

save stock_panel, replace

*** (2) By PEG ratio investment
use stock_panel, clear
keep date_yq market_re stock_pe ew_rt vw_rt vw_rd vw_inc pe_median_all pe_median l_pe_median
bys market_re: egen mean_ew_rt = mean(ew_rt) // equal-weighted
bys market_re: egen mean_vw_rt = mean(vw_rt) // value-weighted
bys market_re: egen mean_vw_rd = mean(vw_rd) // value-weighted
bys market_re: egen mean_vw_inc = mean(vw_inc) // value-weighted


* Generate reinvestment ratio
gen stock_reinv = mean_vw_rd / mean_vw_inc *100
gen stock_grow = stock_reinv * mean_vw_rt *100

duplicates drop date_yq market_re, force

gen stock_peg = pe_median_all / stock_grow
duplicates drop market_re, force
keep market_re pe_median_all stock_peg mean_vw_rt

*** (3) By P/E ROE investment
use stock_panel, clear
keep date_yq market_re stock_pe vw_rt pe_median_all pe_median
bys market_re: egen mean_vw_rt = mean(vw_rt)
duplicates drop date_yq market_re, force
keep if date_yq == quarterly("2022q4","YQ")|date_yq == quarterly("2021q4","YQ")
keep date_yq market_re pe_median_all mean_vw_rt pe_median vw_rt

*** (4) Plot P/E ratio time series
use stock_panel, clear
bytwoway line pe_median date_yq,by(market_re)
