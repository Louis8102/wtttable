version 19.5
clear all
set more off

* Example for wtttable using Stata's auto data.
* Requires owablock if blockfromchar is used.

sysuse auto, clear

owablock, blocks("Cost: price" "Vehicle Performance: mpg weight length") replace
local outcomes `r(varlist)'

wtttable `outcomes', by(foreign) blockfromchar ///
    saving(wtttable_example.docx) ///
    mapdoc(wtttable_mapping.docx) ///
    labelmode(item) ///
    results(wtttable_example_results.dta) ///
    show(all) replace
