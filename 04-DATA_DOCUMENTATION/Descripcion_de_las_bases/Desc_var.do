quietly describe
if r(k) > r(N)  set obs `r(k)'
 foreach new in newlist varname varlabel {
    quietly  generate `new' = ""
} 

ds
local varlist `r(varlist)'

local k 1

foreach var of varlist `varlist' {
    local varlabel : variable label `var'
    quietly replace varname = "`var'" in `k'
    quietly replace varlabel = "`varlabel'" in `k'
    local ++k
}

capture{
drop if varname == "newlist" |  varname == "varname" |  varname == "varlabel" 
}

keep  varname varlabel
capture{
drop if varname == "" 
}
