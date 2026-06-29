*! version 1.0.3  29jun2026
program define wtttable, rclass
    version 19.5

    syntax varlist(numeric min=1) [if] [in], ///
        BY(varname) SAVing(string) ///
        [ REPLACE ALPHA(real 0.05) ///
          SHOW(string) SHOWDF AVAILABLECASE ///
          BLOCKFILE(string) BLOCKFROMLABEL BLOCKFROMCHAR SHOWBLOCK ///
          RESULTS(string) EXCEL(string) MAPDOC(string) LABELMODE(string) ///
          MINCELL(integer 2) ///
          TITLE(string) TABLENUMber(string) ///
          NOTE(string) ]

    if `alpha' <= 0 | `alpha' >= 1 {
        di as err "alpha() must be strictly between 0 and 1"
        exit 198
    }
    if `mincell' < 2 {
        di as err "mincell() must be at least 2"
        exit 198
    }

    local show = lower(strtrim(`"`show'"'))
    if `"`show'"' == "" local show "significant"
    if !inlist(`"`show'"', "significant", "all") {
        di as err "show() must be significant or all"
        exit 198
    }

    if `"`title'"' == "" local title "Welch Two-Group Test Results"
    if `"`tablenumber'"' == "" local tablenumber "Table 1"

    local labelmode = lower(strtrim(`"`labelmode'"'))
    if `"`labelmode'"' == "" local labelmode "label"
    if !inlist(`"`labelmode'"', "label", "item") {
        di as err "labelmode() must be label or item"
        exit 198
    }

    local n_block_sources = (`"`blockfile'"' != "") + (`"`blockfromlabel'"' != "") + (`"`blockfromchar'"' != "")
    if `n_block_sources' > 1 {
        di as err "only one of blockfile(), blockfromlabel, or blockfromchar may be specified"
        exit 198
    }

    capture confirm new file `"`saving'"'
    if _rc & `"`replace'"' == "" {
        di as err `"file `saving' already exists; specify replace"'
        exit 602
    }
    if `"`results'"' != "" {
        capture confirm new file `"`results'"'
        if _rc & `"`replace'"' == "" {
            di as err `"file `results' already exists; specify replace"'
            exit 602
        }
    }
    if `"`excel'"' != "" {
        capture confirm new file `"`excel'"'
        if _rc & `"`replace'"' == "" {
            di as err `"file `excel' already exists; specify replace"'
            exit 602
        }
    }
    if `"`mapdoc'"' != "" {
        capture confirm new file `"`mapdoc'"'
        if _rc & `"`replace'"' == "" {
            di as err `"file `mapdoc' already exists; specify replace"'
            exit 602
        }
    }

    marksample touse, novarlist
    markout `touse' `by', strok
    if `"`availablecase'"' == "" markout `touse' `varlist'

    quietly count if `touse'
    if r(N) == 0 {
        di as err "no observations in the analysis sample"
        exit 2000
    }
    local sample_N = r(N)

    preserve
        keep if `touse'

        tempvar gid
        capture confirm numeric variable `by'
        if !_rc {
            quietly egen `gid' = group(`by') if !missing(`by'), label
        }
        else {
            quietly egen `gid' = group(`by') if !missing(`by'), label
        }
        quietly levelsof `gid', local(gids)
        local ngroups : word count `gids'
        if `ngroups' != 2 {
            di as err "by() must identify exactly two observed groups in the analysis sample"
            restore
            exit 198
        }
        local g1 : word 1 of `gids'
        local g2 : word 2 of `gids'

        quietly levelsof `by' if `gid' == `g1', local(orig1) clean
        quietly levelsof `by' if `gid' == `g2', local(orig2) clean
        local group_name1 "`orig1'"
        local group_name2 "`orig2'"
        capture confirm numeric variable `by'
        if !_rc {
            local vallab : value label `by'
            if `"`vallab'"' != "" {
                local first1 : word 1 of `orig1'
                local first2 : word 1 of `orig2'
                local lab1 : label `vallab' `first1'
                local lab2 : label `vallab' `first2'
                if `"`lab1'"' != "" local group_name1 `"`lab1'"'
                if `"`lab2'"' != "" local group_name2 `"`lab2'"'
            }
        }

        if `"`availablecase'"' == "" {
            quietly count if `gid' == `g1'
            local group_N1 = r(N)
            quietly count if `gid' == `g2'
            local group_N2 = r(N)
        }

        tempfile blockmapclean rawresults prefdr fdrvalues fullresults displayresults tabledata
        tempname rawpost

        if `"`blockfile'"' != "" {
            capture confirm file `"`blockfile'"'
            if _rc {
                di as err `"blockfile() not found: `blockfile'"'
                restore
                exit 601
            }
            preserve
                quietly use `"`blockfile'"', clear
                foreach needed in varname blockid blocklabel {
                    capture confirm variable `needed'
                    if _rc {
                        di as err "blockfile() must contain variable `needed'"
                        restore
                        restore
                        exit 111
                    }
                }
                capture confirm string variable varname
                if _rc {
                    di as err "varname in blockfile() must be a string variable"
                    restore
                    restore
                    exit 109
                }
                capture confirm string variable blocklabel
                if _rc {
                    di as err "blocklabel in blockfile() must be a string variable"
                    restore
                    restore
                    exit 109
                }
                keep varname blockid blocklabel
                quietly replace varname = strtrim(varname)
                quietly replace blocklabel = strtrim(blocklabel)
                quietly count if missing(varname) | missing(blockid) | missing(blocklabel)
                if r(N) > 0 {
                    di as err "blockfile() contains missing varname, blockid, or blocklabel"
                    restore
                    restore
                    exit 459
                }
                quietly save `"`blockmapclean'"', replace
            restore
        }

        quietly postfile `rawpost' int item_no ///
            str32 variable str32 label_blockcode str244 label_blocklabel str244 rowlabel ///
            str80 group1 str80 group2 ///
            double n1 mean1 sd1 n2 mean2 sd2 t df p gav se_gav lb_gav ub_gav ///
            using `"`rawresults'"', replace

        local item = 0
        foreach y of varlist `varlist' {
            local ++item
            local ylab : variable label `y'
            local rowlab `"`ylab'"'
            if `"`rowlab'"' == "" local rowlab "`y'"
            local label_blockcode ""
            local label_blocklabel ""

            if `"`blockfromchar'"' != "" {
                local label_blockcode : char `y'[owatable_blockid]
                local label_blocklabel : char `y'[owatable_blocklabel]
                local char_rowlab : char `y'[owatable_label]
                local label_blockcode = strtrim(`"`label_blockcode'"')
                local label_blocklabel = strtrim(`"`label_blocklabel'"')
                if `"`ylab'"' == "" & `"`char_rowlab'"' != "" local rowlab `"`char_rowlab'"'
                if `"`label_blockcode'"' == "" | `"`label_blocklabel'"' == "" {
                    di as err "blockfromchar requires variable characteristics:"
                    di as err `"char `y'[owatable_blockid] "B01""'
                    di as err `"char `y'[owatable_blocklabel] "Block label""'
                    restore
                    exit 198
                }
            }
            else if `"`blockfromlabel'"' != "" {
                local closepos = strpos(`"`ylab'"', "]")
                local pipepos = strpos(`"`ylab'"', "|")
                if substr(`"`ylab'"', 1, 1) == "[" & `closepos' > 0 & `pipepos' > 0 & `pipepos' < `closepos' {
                    local label_blockcode = strtrim(substr(`"`ylab'"', 2, `pipepos' - 2))
                    local label_blocklabel = strtrim(substr(`"`ylab'"', `pipepos' + 1, `closepos' - `pipepos' - 1))
                    local rowlab = strtrim(substr(`"`ylab'"', `closepos' + 1, .))
                    if `"`rowlab'"' == "" local rowlab "`y'"
                }
                else {
                    di as err "blockfromlabel requires variable labels to follow:"
                    di as err "[block_id | block_label] display_label"
                    di as err "variable `y' has label: `ylab'"
                    restore
                    exit 198
                }
            }

            quietly summarize `y' if `gid' == `g1'
            local n1 = r(N)
            local mean1 = r(mean)
            local sd1 = r(sd)
            quietly summarize `y' if `gid' == `g2'
            local n2 = r(N)
            local mean2 = r(mean)
            local sd2 = r(sd)

            local t = .
            local df = .
            local p = .
            local gav = .
            local se_gav = .
            local lb_gav = .
            local ub_gav = .
            if `n1' >= `mincell' & `n2' >= `mincell' & `sd1' > 0 & `sd2' > 0 {
                local v1 = `sd1'^2
                local v2 = `sd2'^2
                local se = sqrt(`v1'/`n1' + `v2'/`n2')
                local t = (`mean1' - `mean2') / `se'
                local df = (`v1'/`n1' + `v2'/`n2')^2 / ((`v1'/`n1')^2/(`n1'-1) + (`v2'/`n2')^2/(`n2'-1))
                local p = 2 * ttail(`df', abs(`t'))
                local sdav = sqrt((`v1' + `v2') / 2)
                local esdf = `n1' + `n2' - 2
                local J = 1 - 3/(4 * `esdf' - 1)
                local gav = `J' * ((`mean1' - `mean2') / `sdav')
                local se_gav = sqrt((`n1' + `n2') / (`n1' * `n2') + (`gav'^2) / (2 * (`n1' + `n2' - 2)))
                local zcrit = invnormal(1 - `alpha'/2)
                local lb_gav = `gav' - `zcrit' * `se_gav'
                local ub_gav = `gav' + `zcrit' * `se_gav'
            }

            post `rawpost' (`item') (`"`y'"') (`"`label_blockcode'"') (`"`label_blocklabel'"') ///
                (`"`rowlab'"') (`"`group_name1'"') (`"`group_name2'"') ///
                (`n1') (`mean1') (`sd1') (`n2') (`mean2') (`sd2') ///
                (`t') (`df') (`p') (`gav') (`se_gav') (`lb_gav') (`ub_gav')
        }
        quietly postclose `rawpost'

        quietly use `"`rawresults'"', clear

        if `"`blockfile'"' != "" {
            quietly drop label_blockcode label_blocklabel
            quietly merge 1:1 variable using `"`blockmapclean'"', keep(master match)
            quietly count if _merge == 1
            if r(N) > 0 {
                di as err "blockfile() does not map all variables in varlist"
                restore
                exit 459
            }
            quietly drop _merge
            capture confirm numeric variable blockid
            if _rc quietly encode blockid, gen(blockid_num)
            else quietly generate double blockid_num = blockid
            quietly drop blockid
            quietly rename blockid_num blockid
            quietly generate str32 blockcode = string(blockid)
        }
        else if `"`blockfromlabel'"' != "" | `"`blockfromchar'"' != "" {
            quietly generate str32 blockcode = label_blockcode
            quietly generate str244 blocklabel = label_blocklabel
            quietly count if missing(blockcode) | missing(blocklabel)
            if r(N) > 0 {
                di as err "could not parse block information for all variables"
                restore
                exit 198
            }
            capture destring blockcode, generate(blockid) ignore("B b _-") force
            quietly count if missing(blockid)
            if r(N) > 0 {
                quietly encode blockcode, generate(blockid2)
                quietly drop blockid
                quietly rename blockid2 blockid
            }
            quietly drop label_blockcode label_blocklabel
        }
        else {
            quietly generate double blockid = 1
            quietly generate str32 blockcode = ""
            quietly generate str244 blocklabel = ""
            quietly drop label_blockcode label_blocklabel
        }

        quietly generate long result_id = _n
        quietly save `"`prefdr'"', replace

        quietly keep result_id p
        quietly keep if !missing(p)
        quietly sort p result_id
        quietly generate long fdr_rank = _n
        quietly count
        quietly generate long fdr_m = r(N)
        quietly generate double q = p * fdr_m / fdr_rank
        quietly gsort -fdr_rank
        quietly replace q = min(q, q[_n-1]) if _n > 1
        quietly replace q = min(q, 1)
        quietly keep result_id q
        quietly save `"`fdrvalues'"', replace

        quietly use `"`prefdr'"', clear
        quietly merge 1:1 result_id using `"`fdrvalues'"', nogen

        quietly generate byte showrow = 1
        if `"`show'"' == "significant" {
            quietly replace showrow = !missing(q) & q < `alpha'
        }

        quietly generate str12 mean_txt1 = cond(missing(mean1), ".", strtrim(string(mean1, "%9.2f")))
        quietly generate str14 sd_txt1 = cond(missing(sd1), "(.)", "(" + strtrim(string(sd1, "%9.2f")) + ")")
        quietly generate str12 mean_txt2 = cond(missing(mean2), ".", strtrim(string(mean2, "%9.2f")))
        quietly generate str14 sd_txt2 = cond(missing(sd2), "(.)", "(" + strtrim(string(sd2, "%9.2f")) + ")")

        quietly generate str18 t_txt = cond(missing(t), ".", strtrim(string(t, "%9.2f")))
        quietly generate str18 df_txt = cond(missing(df), ".", strtrim(string(df, "%9.2f")))
        quietly generate str12 p_txt = cond(missing(p), ".", cond(p < .001, "<.001", subinstr(strtrim(string(p, "%9.3f")), "0.", ".", 1)))
        quietly generate str12 q_txt = cond(missing(q), ".", cond(q < .001, "<.001", subinstr(strtrim(string(q, "%9.3f")), "0.", ".", 1)))
        quietly generate double abs_gav = abs(gav)
        quietly generate double abs_lb_gav = min(abs(lb_gav), abs(ub_gav)) if !missing(lb_gav) & !missing(ub_gav) & lb_gav * ub_gav > 0
        quietly generate double abs_ub_gav = max(abs(lb_gav), abs(ub_gav)) if !missing(lb_gav) & !missing(ub_gav) & lb_gav * ub_gav > 0
        quietly replace abs_lb_gav = 0 if !missing(lb_gav) & !missing(ub_gav) & lb_gav * ub_gav <= 0
        quietly replace abs_ub_gav = max(abs(lb_gav), abs(ub_gav)) if !missing(lb_gav) & !missing(ub_gav) & lb_gav * ub_gav <= 0
        quietly generate str8 gav_num_txt = ""
        quietly replace gav_num_txt = string(abs_gav, "%4.2f") if !missing(q) & q < `alpha'
        quietly generate str4 star_txt = ""
        quietly replace star_txt = "***" if !missing(q) & q < .001
        quietly replace star_txt = "**" if !missing(q) & q < .01 & q >= .001
        quietly replace star_txt = "*" if !missing(q) & q < `alpha' & q >= .01
        quietly generate str16 gav_txt = gav_num_txt + star_txt if gav_num_txt != ""
        quietly generate str32 ci_txt = ""
        quietly replace ci_txt = "[" + string(abs_lb_gav, "%4.2f") + ", " + string(abs_ub_gav, "%4.2f") + "]" if !missing(lb_gav) & !missing(ub_gav)
        quietly count
        local item_digits = max(2, length(string(r(N))))
        local item_fmt "%0`item_digits'.0f"
        quietly generate str16 itemcode = "Item" + string(item_no, "`item_fmt'")
        quietly generate str244 displaylabel = rowlabel
        if `"`labelmode'"' == "item" {
            quietly replace displaylabel = itemcode
        }

        if `"`results'"' != "" {
            quietly save `"`results'"', replace
        }

        quietly keep if showrow
        quietly count
        local n_display = r(N)
        if `n_display' == 0 {
            di as err "no rows selected for display; try show(all)"
            restore
            exit 2000
        }

        quietly sort blockid item_no
        quietly save `"`tabledata'"', replace

        quietly generate int label_chars = ustrlen(displaylabel)
        quietly generate int block_chars = ustrlen(blocklabel)
        quietly generate int display_chars = max(label_chars, block_chars)
        quietly summarize display_chars
        local max_label_chars = r(max)
        quietly drop label_chars block_chars display_chars

        quietly levelsof blockid if blocklabel != "", local(blocks_shown)
        local nblocks_shown : word count `blocks_shown'
        local use_blocks = ((`"`blockfile'"' != "" | `"`blockfromlabel'"' != "" | `"`blockfromchar'"' != "") & (`nblocks_shown' > 1 | `"`showblock'"' != ""))

        local doc_font "Times New Roman"
        local doc_font_size = 10
        local sub1 = uchar(8321)
        local sub2 = uchar(8322)

        if `"`mapdoc'"' != "" {
            quietly use `"`tabledata'"', clear
            local map_rows = _N + 1
            quietly generate int map_item_chars = max(ustrlen(itemcode), ustrlen("Item"))
            quietly generate int map_var_chars = max(ustrlen(variable), ustrlen("Variable"))
            quietly generate int map_label_chars = max(ustrlen(rowlabel), ustrlen("Item label"))
            quietly generate int map_block_chars = max(ustrlen(blocklabel), ustrlen("Block"))
            quietly summarize map_item_chars
            local map_item_width = min(0.80, max(0.55, r(max) * 0.070 + 0.16))
            quietly summarize map_var_chars
            local map_var_width = min(1.20, max(0.75, r(max) * 0.065 + 0.18))
            quietly summarize map_label_chars
            local map_label_width = min(5.75, max(1.60, r(max) * 0.072 + 0.22))
            quietly summarize map_block_chars
            local map_block_width = min(2.35, max(1.10, r(max) * 0.072 + 0.22))
            quietly drop map_item_chars map_var_chars map_label_chars map_block_chars
            local map_no_width = 0.45
            local map_total_width = `map_no_width' + `map_item_width' + `map_var_width' + `map_label_width' + `map_block_width'
            local map_total_txt : display %6.3f `map_total_width'
            local map_total_txt = strtrim("`map_total_txt'") + "in"
            local map_item_txt : display %6.3f `map_item_width'
            local map_item_txt = strtrim("`map_item_txt'") + "in"
            local map_var_txt : display %6.3f `map_var_width'
            local map_var_txt = strtrim("`map_var_txt'") + "in"
            local map_label_txt : display %6.3f `map_label_width'
            local map_label_txt = strtrim("`map_label_txt'") + "in"
            local map_block_txt : display %6.3f `map_block_width'
            local map_block_txt = strtrim("`map_block_txt'") + "in"
            putdocx clear
            putdocx begin, pagesize(letter) landscape margin(left, .55) margin(right, .55) font("`doc_font'", 12)
            putdocx paragraph, spacing(before, 0pt) spacing(after, 0pt)
            putdocx text ("Appendix A"), bold
            putdocx paragraph, spacing(before, 0pt) spacing(after, 4pt)
            putdocx text ("Item Labels and Subscale Mapping"), italic
            putdocx table maptbl = (`map_rows', 5), width(`map_total_txt') halign(left) ///
                border(all, nil) cellmargin(top, 2pt) cellmargin(bottom, 2pt) ///
                cellmargin(left, 2pt) cellmargin(right, 2pt)
            putdocx table maptbl(1,1) = ("No.")
            putdocx table maptbl(1,2) = ("Item")
            putdocx table maptbl(1,3) = ("Variable")
            putdocx table maptbl(1,4) = ("Item label")
            putdocx table maptbl(1,5) = ("Block")
            putdocx table maptbl(1,.), bold halign(center) border(top, single, black, 1.25pt) border(bottom, single, black, .5pt)
            forvalues i = 1/`=_N' {
                local r = `i' + 1
                putdocx table maptbl(`r',1) = (item_no[`i'])
                putdocx table maptbl(`r',2) = (itemcode[`i'])
                putdocx table maptbl(`r',3) = (variable[`i'])
                putdocx table maptbl(`r',4) = (rowlabel[`i'])
                putdocx table maptbl(`r',5) = (blocklabel[`i'])
            }
            putdocx table maptbl(`map_rows',.), border(bottom, single, black, 1.25pt)
            putdocx table maptbl(.,.), font("`doc_font'", 12) valign(top)
            putdocx table maptbl(2/`map_rows',1), halign(center)
            putdocx table maptbl(2/`map_rows',2), halign(center)
            putdocx table maptbl(2/`map_rows',3), halign(left)
            putdocx table maptbl(2/`map_rows',4), halign(left)
            putdocx table maptbl(2/`map_rows',5), halign(left)
            putdocx table maptbl(.,1), width(.45in)
            putdocx table maptbl(.,2), width(`map_item_txt')
            putdocx table maptbl(.,3), width(`map_var_txt')
            putdocx table maptbl(.,4), width(`map_label_txt')
            putdocx table maptbl(.,5), width(`map_block_txt')
            putdocx save `"`mapdoc'"', replace nomsg
            quietly use `"`tabledata'"', clear
        }

        if `"`excel'"' != "" {
            quietly putexcel set `"`excel'"', replace
            quietly putexcel A1 = (`"`tablenumber'"'), bold font("Times New Roman", 12)
            quietly putexcel A2 = (`"`title'"'), italic font("Times New Roman", 12)

            quietly putexcel A3 = ("Variable"), hcenter
            if `"`availablecase'"' == "" {
                quietly putexcel B3:C3 = (`"G`sub1' (n`sub1'=`group_N1')"'), merge hcenter border(bottom)
                quietly putexcel D3:E3 = (`"G`sub2' (n`sub2'=`group_N2')"'), merge hcenter border(bottom)
            }
            else {
                quietly putexcel B3:C3 = (`"G`sub1'"'), merge hcenter border(bottom)
                quietly putexcel D3:E3 = (`"G`sub2'"'), merge hcenter border(bottom)
            }
            quietly putexcel F3 = ("t"), italic hcenter
            quietly putexcel G3 = ("df"), italic hcenter
            quietly putexcel H3 = ("p"), italic hcenter
            quietly putexcel I3 = ("FDR q"), italic hcenter
            quietly putexcel J3 = ("Effect Size"), hcenter
            quietly putexcel K3 = ("95% CI"), hcenter

            quietly putexcel B4 = ("M"), italic hcenter
            quietly putexcel C4 = ("SD"), italic hcenter
            quietly putexcel D4 = ("M"), italic hcenter
            quietly putexcel E4 = ("SD"), italic hcenter
            quietly putexcel J4 = (`"G`sub1'-G`sub2'"'), hcenter

            quietly putexcel A3:K3, border(top) font("Times New Roman", 12)
            quietly putexcel A4:K4, border(bottom) font("Times New Roman", 12)

            local xrow = 4
            quietly use `"`tabledata'"', clear
            if `use_blocks' {
                foreach b of local blocks_shown {
                    local ++xrow
                    quietly levelsof blocklabel if blockid == `b', local(thisblock) clean
                    quietly putexcel A`xrow' = (`"`thisblock'"'), bold italic font("Times New Roman", 12)
                    forvalues i = 1/`=_N' {
                        if blockid[`i'] == `b' {
                            local ++xrow
                            local thislabel `"`=displaylabel[`i']'"'
                            quietly putexcel A`xrow' = (`"   `thislabel'"')
                            quietly putexcel B`xrow' = (mean_txt1[`i'])
                            quietly putexcel C`xrow' = (sd_txt1[`i'])
                            quietly putexcel D`xrow' = (mean_txt2[`i'])
                            quietly putexcel E`xrow' = (sd_txt2[`i'])
                            quietly putexcel F`xrow' = (t_txt[`i'])
                            quietly putexcel G`xrow' = (df_txt[`i'])
                            quietly putexcel H`xrow' = (p_txt[`i'])
                            quietly putexcel I`xrow' = (q_txt[`i'])
                            quietly putexcel J`xrow' = (gav_txt[`i'])
                            quietly putexcel K`xrow' = (ci_txt[`i'])
                        }
                    }
                }
            }
            else {
                forvalues i = 1/`=_N' {
                local ++xrow
                local thislabel `"`=displaylabel[`i']'"'
                quietly putexcel A`xrow' = (`"`thislabel'"')
                quietly putexcel B`xrow' = (mean_txt1[`i'])
                quietly putexcel C`xrow' = (sd_txt1[`i'])
                quietly putexcel D`xrow' = (mean_txt2[`i'])
                quietly putexcel E`xrow' = (sd_txt2[`i'])
                quietly putexcel F`xrow' = (t_txt[`i'])
                quietly putexcel G`xrow' = (df_txt[`i'])
                quietly putexcel H`xrow' = (p_txt[`i'])
                quietly putexcel I`xrow' = (q_txt[`i'])
                quietly putexcel J`xrow' = (gav_txt[`i'])
                quietly putexcel K`xrow' = (ci_txt[`i'])
            }
        }

        local note_row = `xrow' + 1
        quietly putexcel A`note_row':K`note_row', border(top)
            quietly putexcel A`note_row' = ("Note. G1 = `group_name1'; G2 = `group_name2'. Effect sizes are absolute Hedges' g_av values for FDR-significant tests. CIs are approximate 95% confidence intervals for absolute Hedges' g_av. Signed effect sizes and signed CIs are saved in results().")
        quietly putexcel A1:K`note_row', font("Times New Roman", 12)
        quietly putexcel A5:A`xrow', left
        quietly putexcel B5:K`xrow', right
        quietly putexcel A1:K`note_row', txtwrap
            capture quietly _wtttable_xlsx_widths `"`excel'"'
            quietly use `"`tabledata'"', clear
        }

        local var_width_min = 1.250
        local var_width_max = 4.100
        local char_width = 0.070
        local var_padding = 0.200
        local var_width = min(`var_width_max', max(`var_width_min', (`max_label_chars' * `char_width') + `var_padding'))
        local mean_width = 0.430
        local sd_width = 0.520
        local stat_width = 0.420
        local df_width = 0.500
        local p_width = 0.420
        local q_width = 0.520
        local es_width = 0.560
        local ci_width = 0.980
        local gap_width = 0.045
        local width_total = `var_width' + 2*`mean_width' + 2*`sd_width' + 6*`gap_width' + `stat_width' + `df_width' + `p_width' + `q_width' + `es_width' + `ci_width'
        local width_total_txt : display %6.3f `width_total'
        local width_total_txt = strtrim("`width_total_txt'") + "in"

        local ncols = 16
        local header_rows = 2
        local note_rows = 1
        local nrows = `header_rows' + `n_display' + `note_rows'
        if `use_blocks' local nrows = `nrows' + `nblocks_shown'

        local var_col = 1
        local g1_m = 2
        local g1_sd = 3
        local gap1 = 4
        local g2_m = 5
        local g2_sd = 6
        local gap2 = 7
        local t_col = 8
        local df_col = 9
        local gap3 = 10
        local p_col = 11
        local gap4 = 12
        local q_col = 13
        local gap5 = 14
        local es_col = 15
        local ci_col = 16
        local gap_cols "`gap1' `gap2' `gap3' `gap4' `gap5'"

        putdocx clear
        putdocx begin, pagesize(letter) landscape margin(left, .55) margin(right, .55) font("`doc_font'", `doc_font_size')
        putdocx paragraph, spacing(before, 0pt) spacing(after, 0pt)
        putdocx text (`"`tablenumber'"'), bold
        putdocx paragraph, spacing(before, 0pt) spacing(after, 0pt)
        putdocx text (`"`title'"'), italic
        putdocx table owatbl = (`nrows', `ncols'), width(`width_total_txt') halign(left) ///
            border(all, nil) cellmargin(top, .5pt) cellmargin(bottom, 0pt) ///
            cellmargin(left, 2pt) cellmargin(right, 2pt)

        local c = 1
        foreach w in `var_width' `mean_width' `sd_width' `gap_width' `mean_width' `sd_width' `gap_width' `stat_width' `df_width' `gap_width' `p_width' `gap_width' `q_width' `gap_width' `es_width' `ci_width' {
            local cw : display %6.3f `w'
            local cw = strtrim("`cw'") + "in"
            putdocx table owatbl(.,`c'), width(`cw')
            local ++c
        }

        putdocx table owatbl(1,`var_col') = ("Variable")
        foreach c of local gap_cols {
            putdocx table owatbl(1,`c') = ("")
            putdocx table owatbl(2,`c') = ("")
            putdocx table owatbl(1,`c'), border(bottom, nil)
        }
        putdocx table owatbl(1,`t_col') = ("t")
        putdocx table owatbl(1,`t_col'), italic
        putdocx table owatbl(1,`df_col') = ("df")
        putdocx table owatbl(1,`df_col'), italic
        putdocx table owatbl(1,`p_col') = ("p")
        putdocx table owatbl(1,`p_col'), italic
        putdocx table owatbl(1,`q_col') = ("FDR q")
        putdocx table owatbl(1,`q_col'), italic
        putdocx table owatbl(1,`es_col') = ("Effect Size")
        putdocx table owatbl(1,`ci_col') = ("95% CI")
        forvalues c = 1/`ncols' {
            putdocx table owatbl(1,`c'), border(bottom, nil)
        }

        if `"`availablecase'"' == "" {
            putdocx table owatbl(1,`g2_m'), colspan(2) halign(center) border(bottom, single, black, .5pt)
            putdocx table owatbl(1,`g2_m') = (`"G`sub2' (n`sub2'=`group_N2')"')
            putdocx table owatbl(1,`g1_m'), colspan(2) halign(center) border(bottom, single, black, .5pt)
            putdocx table owatbl(1,`g1_m') = (`"G`sub1' (n`sub1'=`group_N1')"')
        }
        else {
            putdocx table owatbl(1,`g2_m'), colspan(2) halign(center) border(bottom, single, black, .5pt)
            putdocx table owatbl(1,`g2_m') = ("G`sub2'")
            putdocx table owatbl(1,`g1_m'), colspan(2) halign(center) border(bottom, single, black, .5pt)
            putdocx table owatbl(1,`g1_m') = ("G`sub1'")
        }

        foreach c in `g1_m' `g2_m' {
            putdocx table owatbl(2,`c') = ("M")
            putdocx table owatbl(2,`c'), italic
        }
        foreach c in `g1_sd' `g2_sd' {
            putdocx table owatbl(2,`c') = ("SD")
            putdocx table owatbl(2,`c'), italic
        }
        foreach c in `var_col' `t_col' `df_col' `p_col' `q_col' `es_col' `ci_col' {
            putdocx table owatbl(2,`c') = ("")
        }
        putdocx table owatbl(2,`es_col') = ("G`sub1'-G`sub2'")
        local row = `header_rows'
        local section_rows ""
        quietly use `"`tabledata'"', clear
        if `use_blocks' {
            foreach b of local blocks_shown {
                local ++row
                local section_rows `"`section_rows' `row'"'
                quietly levelsof blocklabel if blockid == `b', local(thisblock) clean
                putdocx table owatbl(`row',`var_col') = (`"`thisblock'"')
                forvalues c = 2/`ncols' {
                    putdocx table owatbl(`row',`c') = ("")
                }
                forvalues i = 1/`=_N' {
                    if blockid[`i'] == `b' {
                        local ++row
                        local thislabel `"`=displaylabel[`i']'"'
                        putdocx table owatbl(`row',`var_col') = (`"   `thislabel'"')
                        putdocx table owatbl(`row',`g1_m') = (mean_txt1[`i'])
                        putdocx table owatbl(`row',`g1_sd') = (sd_txt1[`i'])
                        putdocx table owatbl(`row',`g2_m') = (mean_txt2[`i'])
                        putdocx table owatbl(`row',`g2_sd') = (sd_txt2[`i'])
                        putdocx table owatbl(`row',`t_col') = (t_txt[`i'])
                        putdocx table owatbl(`row',`df_col') = (df_txt[`i'])
                        putdocx table owatbl(`row',`p_col') = (p_txt[`i'])
                        putdocx table owatbl(`row',`q_col') = (q_txt[`i'])
                        putdocx table owatbl(`row',`es_col') = (gav_txt[`i'])
                        putdocx table owatbl(`row',`ci_col') = (ci_txt[`i'])
                        foreach c of local gap_cols {
                            putdocx table owatbl(`row',`c') = ("")
                        }
                    }
                }
            }
        }
        else {
            forvalues i = 1/`=_N' {
                local ++row
                local thislabel `"`=displaylabel[`i']'"'
                putdocx table owatbl(`row',`var_col') = (`"`thislabel'"')
                putdocx table owatbl(`row',`g1_m') = (mean_txt1[`i'])
                putdocx table owatbl(`row',`g1_sd') = (sd_txt1[`i'])
                putdocx table owatbl(`row',`g2_m') = (mean_txt2[`i'])
                putdocx table owatbl(`row',`g2_sd') = (sd_txt2[`i'])
                putdocx table owatbl(`row',`t_col') = (t_txt[`i'])
                putdocx table owatbl(`row',`df_col') = (df_txt[`i'])
                putdocx table owatbl(`row',`p_col') = (p_txt[`i'])
                putdocx table owatbl(`row',`q_col') = (q_txt[`i'])
                putdocx table owatbl(`row',`es_col') = (gav_txt[`i'])
                putdocx table owatbl(`row',`ci_col') = (ci_txt[`i'])
                foreach c of local gap_cols {
                    putdocx table owatbl(`row',`c') = ("")
                }
            }
        }

        local note_row = `nrows'
        local sample_text "A common complete-case sample was used across all outcomes and the grouping variable. "
        if `"`availablecase'"' != "" local sample_text "Outcome-specific available cases were used; group Ns may vary by outcome. "
        local df_text "Welch-Satterthwaite degrees of freedom are reported in the df column. "

        putdocx table owatbl(`note_row',1), colspan(`ncols') halign(left) valign(top) border(top, single, black, 1.25pt)
        putdocx table owatbl(`note_row',1) = ("Note. "), italic
        putdocx table owatbl(`note_row',1) = ("G"), append
        putdocx table owatbl(`note_row',1) = ("1"), append script(sub)
        putdocx table owatbl(`note_row',1) = (`" = `group_name1'; "'), append
        putdocx table owatbl(`note_row',1) = ("G"), append
        putdocx table owatbl(`note_row',1) = ("2"), append script(sub)
        putdocx table owatbl(`note_row',1) = (`" = `group_name2'. `sample_text'Welch independent-samples t tests were used. FDR q-values are Benjamini-Hochberg adjusted p-values. The effect-size column reports absolute Hedges' "'), append
        putdocx table owatbl(`note_row',1) = ("g"), append italic
        putdocx table owatbl(`note_row',1) = ("av"), append script(sub)
        putdocx table owatbl(`note_row',1) = (`" values for FDR-significant tests. 95% CIs are approximate confidence intervals for absolute Hedges' g_av; signed effect sizes and signed CIs are saved in results(). Blank cells indicate nonsignificant FDR-adjusted tests. `df_text'*"'), append
        putdocx table owatbl(`note_row',1) = ("p"), append italic
        putdocx table owatbl(`note_row',1) = (" < .05. **"), append
        putdocx table owatbl(`note_row',1) = ("p"), append italic
        putdocx table owatbl(`note_row',1) = (" < .01. ***"), append
        putdocx table owatbl(`note_row',1) = ("p"), append italic
        putdocx table owatbl(`note_row',1) = (" < .001."), append
        if `"`note'"' != "" putdocx table owatbl(`note_row',1) = (`" `note'"'), append

        putdocx table owatbl(.,.), font("`doc_font'", `doc_font_size') valign(center)
        putdocx table owatbl(1/2,.), halign(center)
        putdocx table owatbl(1,`g1_m'), halign(center)
        putdocx table owatbl(1,`g2_m'), halign(center)
        putdocx table owatbl(2,`g1_m'), halign(center)
        putdocx table owatbl(2,`g1_sd'), halign(center)
        putdocx table owatbl(2,`g2_m'), halign(center)
        putdocx table owatbl(2,`g2_sd'), halign(center)
        putdocx table owatbl(2,`es_col'), halign(center)
        putdocx table owatbl(1,`ci_col'), halign(center)

        putdocx table owatbl(1,.), border(top, single, black, 1.25pt)
        putdocx table owatbl(2,.), border(bottom, single, black, .5pt)

        putdocx table owatbl(3/`=`nrows'-1',1), halign(left)
        foreach sr of local section_rows {
            putdocx table owatbl(`sr',1), bold italic halign(left)
        }
        putdocx table owatbl(3/`=`nrows'-1',`g1_m'), halign(right)
        putdocx table owatbl(3/`=`nrows'-1',`g1_sd'), halign(left)
        putdocx table owatbl(3/`=`nrows'-1',`g2_m'), halign(right)
        putdocx table owatbl(3/`=`nrows'-1',`g2_sd'), halign(left)
        putdocx table owatbl(3/`=`nrows'-1',`t_col'), halign(right)
        putdocx table owatbl(3/`=`nrows'-1',`df_col'), halign(right)
        putdocx table owatbl(3/`=`nrows'-1',`p_col'), halign(right)
        putdocx table owatbl(3/`=`nrows'-1',`q_col'), halign(right)
        putdocx table owatbl(3/`=`nrows'-1',`es_col'), halign(left)
        putdocx table owatbl(3/`=`nrows'-1',`ci_col'), halign(left)
        putdocx table owatbl(`note_row',1), halign(left)

        putdocx save `"`saving'"', replace nomsg

        di as txt "wtttable complete"
        di as txt "Complete-case sample: " as result `sample_N'
        if `"`availablecase'"' == "" {
            di as txt "Group sizes: " as result "G1=`group_N1', G2=`group_N2'"
        }
        di as txt "Word table saved to:"
        di as result `"  {browse `saving'}"'
        if `"`excel'"' != "" {
            di as txt "Excel results saved to:"
            di as result `"  {browse `excel'}"'
        }
        if `"`mapdoc'"' != "" {
            di as txt "Mapping document saved to:"
            di as result `"  {browse `mapdoc'}"'
        }

        return scalar N = `sample_N'
        if `"`availablecase'"' == "" {
            return scalar N_g1 = `group_N1'
            return scalar N_g2 = `group_N2'
        }
        return local saving `"`saving'"'
        if `"`excel'"' != "" return local excel `"`excel'"'
        if `"`mapdoc'"' != "" return local mapdoc `"`mapdoc'"'
    restore
end

program define _wtttable_xlsx_widths
    version 19.5
    args xlsx
    mata: _wtttable_xlsx_widths_mata(`"`xlsx'"')
end

mata:
void _wtttable_xlsx_widths_mata(string scalar xlsx)
{
    class xl scalar B
    B = xl()
    B.load_book(xlsx)
    B.set_sheet("Sheet1")
    B.set_column_width(1, 1, 36)
    B.set_column_width(2, 2, 10)
    B.set_column_width(3, 3, 12)
    B.set_column_width(4, 4, 10)
    B.set_column_width(5, 5, 12)
    B.set_column_width(6, 6, 9)
    B.set_column_width(7, 7, 9)
    B.set_column_width(8, 8, 9)
    B.set_column_width(9, 9, 10)
    B.set_column_width(10, 10, 20)
    B.set_column_width(11, 11, 22)
    B.close_book()
}
end
