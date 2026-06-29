# wtttable

`wtttable` creates APA-style Word tables for multiple two-group Welch independent-samples tests, with Benjamini-Hochberg FDR-adjusted p-values, Welch df, absolute Hedges' g_av effect sizes, and approximate 95% CIs for absolute Hedges' g_av.

Use `labelmode(item)` to display compact Item01-style labels in the main table and `mapdoc()` to create a separate landscape Word document mapping each item to its full label and block/subscale. Use `results()` to save the machine-readable analytic dataset with raw statistics, signed effect sizes, standard errors, and signed confidence limits.

`excel()` is available as an optional export of the same APA-style table layout, but the main workflow is Word table + Word mapping document + Stata results dataset.

It is designed for baseline or preliminary difference tables with exactly two independent groups.

Install from GitHub:

```stata
net install wtttable, from("https://raw.githubusercontent.com/Louis8102/wtttable/main/") replace
```

Example:

```stata
sysuse auto, clear
owablock, blocks("Cost: price" "Vehicle Performance: mpg weight length") replace
local outcomes `r(varlist)'

wtttable `outcomes', by(foreign) blockfromchar ///
    saving(table1.docx) ///
    mapdoc(mapping.docx) ///
    labelmode(item) ///
    results(table1_results.dta) ///
    show(all) replace
```

Author: Hao Ma
