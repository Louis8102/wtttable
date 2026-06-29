{smcl}
{* *! version 1.0.3  29jun2026}{...}
{vieweralsosee "[R] ttest" "help ttest"}{...}
{vieweralsosee "[R] putdocx" "help putdocx"}{...}
{vieweralsosee "owatable" "help owatable"}{...}
{vieweralsosee "owablock" "help owablock"}{...}

{title:Title}

{phang}
{bf:wtttable} {hline 2} Word table for two-group Welch independent-samples
tests, FDR adjustment, and Hedges' g_av

{title:Syntax}

{p 8 17 2}
{cmd:wtttable} {it:varlist} {ifin}{cmd:,}
{opt by(varname)}
{opt saving(filename)}
[{it:options}]

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{p2coldent :* {opt by(varname)}}two-level grouping variable{p_end}
{p2coldent :* {opt saving(filename)}}Word .docx file to create{p_end}
{synopt:{opt replace}}replace existing output files{p_end}
{synopt:{opt alpha(#)}}significance level; default is {cmd:alpha(.05)}{p_end}
{synopt:{opt show(significant|all)}}select rows shown in the Word table{p_end}
{synopt:{opt showdf}}accepted for backward compatibility; df is now reported in its own column{p_end}
{synopt:{opt availablecase}}use outcome-specific available cases instead of a common complete-case sample{p_end}
{synopt:{opt blockfile(filename)}}map variables to block/subscale headings{p_end}
{synopt:{opt blockfromchar}}extract block/subscale headings from variable characteristics{p_end}
{synopt:{opt blockfromlabel}}extract block/subscale headings from variable labels{p_end}
{synopt:{opt showblock}}show a block heading even when only one block is present{p_end}
{synopt:{opt results(filename)}}save machine-readable analytic results{p_end}
{synopt:{opt excel(filename)}}optionally save the same APA-style table to Excel{p_end}
{synopt:{opt labelmode(label|item)}}display full labels or compact Item01-style labels in the main table{p_end}
{synopt:{opt mapdoc(filename)}}save a separate Word mapping document for item labels and blocks{p_end}
{synopt:{opt mincell(#)}}minimum group-specific N required for an outcome; default is {cmd:mincell(2)}{p_end}
{synopt:{opt title(text)}}set the italic table title{p_end}
{synopt:{opt tablenumber(text)}}set the table identifier; default is {cmd:Table 1}{p_end}
{synopt:{opt note(text)}}append text to the table note{p_end}
{synoptline}
{p 4 6 2}* {opt by()} and {opt saving()} are required.{p_end}

{title:Description}

{pstd}
{cmd:wtttable} creates a landscape Word table for multiple numeric outcomes
compared across exactly two independent groups.  The table reports group means
and standard deviations, Welch independent-samples t tests, Benjamini-Hochberg
FDR-adjusted p-values, Welch df, absolute Hedges' g_av effect sizes, and
approximate 95% confidence intervals for absolute Hedges' g_av.

{pstd}
The command is intended for baseline or preliminary difference tables with two
independent groups, such as treatment versus control or intervention versus
comparison.  It is not designed for paired or dependent samples, such as pre/post
measurements on the same cases.

{pstd}
By default, {cmd:wtttable} uses a common complete-case sample across all
outcomes in {it:varlist} and the grouping variable specified in {opt by()}.
Specify {opt availablecase} only when outcome-specific samples are desired.

{pstd}
By default, only rows with FDR-adjusted p-values below {cmd:alpha()} are
displayed.  Specify {cmd:show(all)} to display all analyzable outcomes.

{title:Options}

{phang}
{opt by(varname)} specifies the grouping variable.  The analysis sample must
contain exactly two observed groups.  Numeric and string grouping variables are
allowed; value labels are used in the table note when available.

{phang}
{opt saving(filename)} specifies the Word document to create.  A {cmd:.docx}
extension is recommended.

{phang}
{opt replace} permits replacement of existing output files.

{phang}
{opt alpha(#)} sets the significance level used for the FDR-adjusted decisions.
The default is {cmd:alpha(.05)}.

{phang}
{opt show(significant)} displays outcomes with significant FDR-adjusted
p-values.  This is the default.

{phang}
{opt show(all)} displays all analyzable outcomes.  This is useful for checking
the full output or for reporting nonsignificant results.

{phang}
{opt showdf} is accepted for backward compatibility.  Current versions report
Welch-Satterthwaite degrees of freedom in a separate df column.

{phang}
{opt availablecase} uses all nonmissing observations available for each outcome.
With this option, sample sizes may vary across outcomes; the Word table note
states this explicitly.  Without this option, {cmd:wtttable} uses a common
complete-case sample.

{phang}
{opt blockfromchar} reads block metadata written by {cmd:owablock}.  Each
outcome variable must contain characteristics {cmd:owatable_blockid} and
{cmd:owatable_blocklabel}.  If {cmd:owatable_label} is present, it is used as
the row label.

{phang}
{opt blockfromlabel} extracts block metadata from variable labels formatted as
{cmd:[block_id | block_label] display_label}.

{phang}
{opt blockfile(filename)} specifies a Stata dataset mapping variables to block
headings.  The dataset must contain {cmd:varname}, {cmd:blockid}, and
{cmd:blocklabel}.

{phang}
{opt results(filename)} saves a Stata dataset containing the analytic results,
including means, standard deviations, t statistics, degrees of freedom, raw
p-values, FDR q-values, signed Hedges' g_av, its standard error, and approximate
95% confidence limits.  These signed quantities are intended for users who need
the direction of the group difference.

{phang}
{opt excel(filename)} saves the same APA-style table layout to Excel.  The
Excel table includes the same rows as the Word table and reports df and
approximate 95% confidence intervals for absolute Hedges' g_av.  Use
{opt results(filename)} for the machine-readable analytic dataset.

{phang}
{opt labelmode(label)} displays the variable label in the main table.  This is
the default.

{phang}
{opt labelmode(item)} displays compact item labels such as Item01, Item02, and
Item50 in the main table.  This is useful when long item wording would crowd the
Word table.

{phang}
{opt mapdoc(filename)} creates a separate landscape Word document mapping each compact
item label to the original variable name, full variable label, and block/subscale
heading.  This option is especially useful with {cmd:labelmode(item)}.

{title:Examples}

{pstd}Install both helper and table commands from GitHub:{p_end}

{phang2}{cmd:. net install owablock, from("https://raw.githubusercontent.com/Louis8102/owablock/main/") replace}{p_end}
{phang2}{cmd:. net install wtttable, from("https://raw.githubusercontent.com/Louis8102/wtttable/main/") replace}{p_end}

{pstd}Example using Stata's auto data:{p_end}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. owablock, blocks("Cost: price" "Vehicle Performance: mpg weight length") replace}{p_end}
{phang2}{cmd:. local outcomes `r(varlist)'}{p_end}
{phang2}{cmd:. wtttable `outcomes', by(foreign) blockfromchar saving(table1.docx) mapdoc(mapping.docx) labelmode(item) results(table1_results.dta) show(all) replace}{p_end}

{title:Stored results}

{pstd}
{cmd:wtttable} stores the following in {cmd:r()}:

{synoptset 18 tabbed}{...}
{synopt:{cmd:r(N)}}analysis sample size{p_end}
{synopt:{cmd:r(N_g1)}}group 1 sample size, when common complete-case sampling is used{p_end}
{synopt:{cmd:r(N_g2)}}group 2 sample size, when common complete-case sampling is used{p_end}
{synopt:{cmd:r(saving)}}Word file path{p_end}

{title:Author}

{pstd}
Hao Ma
