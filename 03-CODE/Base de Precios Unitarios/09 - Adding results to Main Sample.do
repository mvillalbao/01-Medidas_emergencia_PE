//------------------------------------------------------------------------------
//		   00 Compras públicas Peru. Importación y limpieza
//------------------------------------------------------------------------------

//Author: Matias Villalba
//Start Date: 09/04/2023
//Input: Bases de los datos abiertos del OSCE

***********************************************************
*	0.          Set up                             
***********************************************************

* 1. Directories _________________________________________________________
version 17

* Directories
	global root 			"C:\Users\matia\OneDrive - Universidad del Pacífico\01-Medidas_emergencia_PE"
	global data_raw			"$root\01-DATA_PERU\01-DATA_RAW"
	global data_pro 		"$root\01-DATA_PERU\02-DATA_PROCESSED"
	global documentation	"$root\01-DATA_PERU\04-DATA_DOCUMENTATION"
	global output			"$root\01-DATA_PERU\02-DATA_PROCESSED\output"
	
	
use "$data_pro\OSCE_computadoras_contratos", clear
	
preserve
import excel using "$data_pro\computer_analysis_dfs\pdf_texts.xlsx", firstrow case(lower) clear
destring n_cod_contrato, replace
foreach i in "extraction_type" {
	encode `i', gen(temp)
	drop `i'
	rename temp `i'
}
tempfile pdf_texts
save `pdf_texts', replace
restore

merge 1:1 n_cod_contrato using `pdf_texts', gen(merge_texts)

preserve
import excel using "$data_pro\computer_analysis_dfs\failed_downloads.xlsx", firstrow case(lower) clear
cap destring n_cod_contrato failed_download, replace
tempfile failed_downloads
save `failed_downloads', replace
restore

merge 1:1 n_cod_contrato using `failed_downloads', nogen
replace failed_download = 0 if failed_download == . 

preserve
import excel using "$data_pro\computer_analysis_dfs\broken_pdfs.xlsx", firstrow case(lower) clear
cap destring n_cod_contrato broken_pdf, replace
tempfile broken_pdfs
save `broken_pdfs', replace
restore

merge 1:1 n_cod_contrato using `broken_pdfs', nogen
replace broken_pdf = 0 if broken_pdf == . 

preserve
import excel using "$data_pro\computer_analysis_dfs\extraction_df.xlsx", firstrow case(lower) clear
cap destring n_cod_contrato, replace
tempfile extraction_df
save `extraction_df', replace
restore

merge 1:1 n_cod_contrato using `extraction_df', nogen keepusing(gpt_unit_prices)

* Count non-missing items for each observation
ds n_item* 
local varlist `r(varlist)'
egen item_count = rownonmiss(`varlist')

gen unit_price_clean = ustrregexra(gpt_unit_prices, "[^0-9;.]","")
split unit_price_clean, gen(unit_price_) parse(";") 
drop unit_price_clean

ds unit_price_* 
local varlist `r(varlist)'
destring `varlist', replace
*egen identified_price_count = rownonmiss(`varlist')


tempfile OSCE_main_sample
save `OSCE_main_sample', replace

keep n_cod_contrato item_count unit_price_*

reshape long unit_price_, i(n_cod_contrato) j(identified_price_id)
rename unit_price_ unit_price


* eliminamos duplicados de todas las variables sin contar product_id (dicha variable indica el sufijo de precio, producto y unidad anterior) para eliminar todas las observaciones vacias en producto_ & precio_ & unidad_ extras.

ds identified_price_id, not
local drop_vars `r(varlist)'
gduplicates drop `drop_vars', force


** Duplicados donde unas observaciones son missings pero al menos una de las observacioes repetida tiene variables procesadas.

* crear nueva variable donde se cuente el numero de obs por id donde producto_ precio_ ni unidad_ son vacios
egen count_nonempty = total(unit_price != .), by(n_cod_contrato)

* Eliminamos observaciones donde producto_ precio_ y unidad_ estan vacias y se tenga count_nonempty mayor a cero
drop if unit_price==. & count_nonempty > 0
drop count_nonempty

bysort n_cod_contrato : gen n_prices_extracted = _N
replace n_prices_extracted = 0 if unit_price==.

sort n_cod_contrato identified_price_id

gen item_group = .
by n_cod_contrato: gen i = _n
by n_cod_contrato: egen total_obs = count(i)
by n_cod_contrato : gen size_per_group = floor(total_obs / item_count)
by n_cod_contrato : replace item_group = ceil(i / size_per_group)



by n_cod_contrato: replace item_group = _n if item_count > total_obs & n_prices_extracted!=0

collapse (mean) mean_unit_price = unit_price item_count n_prices_extracted, by(n_cod_contrato item_group)

drop if item_group>item_count
drop item_count n_prices_extracted

tempfile temp
save `temp', replace

use "$data_pro\OSCE_computadoras_filtrado.dta", clear
sort n_cod_contrato n_item, stable
bysort n_cod_contrato : gen item_group = _n
merge 1:1 n_cod_contrato item_group using `temp', keep(3)

/*
//añadimos codigos de producto mas generales a partir de cubso
preserve
import excel using "$documentation\Catálogo Único de Bienes, Servicios y Obras (CUBSO)\Cubso al 02.07.2023.xlsx", sheet("BIENES.") cellrange(B7) clear
drop if B==""
rename C itemcubso
gen objetocontractual = "Bien"
gen codigoproducto = substr(B, 1, 8)
gen codigoitem = substr(B, 9, 17)
replace codigoitem = ustrregexra(codigoitem, "^0+", "") //le quitamos los ceros innecesarios al codigo de item
destring codigoitem, replace
tempfile codigos_item
save `codigos_item'
restore

merge m:1 codigoitem using `codigos_item', gen(merge_item_2) keep(3) keepusing(itemcubso objetocontractual codigoproducto)

gen codigoproducto_2 = substr(codigoproducto, 1, 4)
*/

gen reporte = (mean_unit_price!=.)

encode codigoentidad, gen(dummyentidad)
encode tipoentidad, gen(dummytipoentidad)
encode sistema_contratacion, gen(dummysistemacontratacion)

*Botamos a las que no panelizan

gen num_contrat = 1 
bys dummyentidad: egen numn_contr_entidad = total(num_contrat)
gen num_contrat_pre = abs(1-d_pandemia)
gen num_contrat_pan = d_pandemia 
bys dummyentidad: egen numn_contr_entidad_prepand = total(num_contrat_pre )
bys dummyentidad: egen numn_contr_entidad_pand = total(num_contrat_pan)
gen panel = numn_contr_entidad_pand > 0 & numn_contr_entidad_prepand > 0
drop numn_contr_entidad num_contrat_pre num_contrat_pan numn_contr_entidad_prepand numn_contr_entidad_pand

keep if mean_unit_price != .

/////////////////////// Bayesian bootstraping set up
cap drop rw1-rw300
set seed 42
exbsample 300 , stub(rw) //numero de repeticiones 
svyset , bsrweight(rw1-rw300) 

 svy bootstrap : reg mean_unit_price i.contratacion##i.d_pandemia
regsave using "$output\regresion_computadores.dta", replace pval autoid  addlabel(model,"1")  detail(scalars)
 svy bootstrap : reg mean_unit_price i.contratacion##i.d_pandemia monto_contratado_total i.dummysistemacontratacion
regsave using "$output\regresion_computadores.dta", append pval autoid  addlabel(model,"2")  detail(scalars)
 svy bootstrap : reg mean_unit_price i.dummyentidad i.contratacion##i.d_pandemia monto_contratado_total i.dummysistemacontratacion
regsave using "$output\regresion_computadores.dta", append pval autoid  addlabel(model,"3")  detail(scalars)
 svy bootstrap : reg mean_unit_price i.dummyentidad i.quarteryear_suscripcion i.contratacion##i.d_pandemia monto_contratado_total i.dummysistemacontratacion
regsave using "$output\regresion_computadores.dta", append pval autoid  addlabel(model,"4")  detail(scalars)


use  "$output\regresion_computadores.dta", clear
keep if var=="mean_unit_price" |  var =="1.d_pandemia" | var =="1.contratacion" | var =="1.contratacion#1.d_pandemia" | var=="_cons"
gen r2_a =  1- (1-r2)*(N_pop-1)/(N_pop-df_m)

replace var = "1.capandemia" if var=="1.d_pandemia"
replace var = "z_cons " if var=="_cons"

tabstat coef pval stderr if model==1, by(var)  save
mat reg1 = r(Stat1)' \ r(Stat2)' \ r(Stat3)' \ r(Stat4)'
tabstat coef pval stderr if model==2, by(var)  save
mat reg2 = r(Stat1)' \ r(Stat2)' \ r(Stat3)' \ r(Stat4)'
tabstat coef pval stderr if model==3, by(var)  save
mat reg3 = r(Stat1)' \ r(Stat2)' \ r(Stat3)'  \ r(Stat4)'
tabstat coef pval stderr if model==4, by(var)  save
mat reg4 = (0, 0, 0)' \ r(Stat1)' \ r(Stat2)' \ r(Stat3)' 
mat reg =  reg1, reg2, reg3, reg4
mat list reg 

tabstat r2_a N, by(model) save 
mat info = r(Stat1) \ r(Stat2) \ r(Stat3) \ r(Stat4)




capture: file close se
file open se using "$output\regresion_computadores.tex", write  replace
local max= 6
//Encabezado
file write se  "\linespread{1} " _n
file write se "\begin{table}[H]" _n
file write se "\centering"  _n
file write se "\caption{Regresión modelo de reporte" _n
file write se "\label{tab:regresion_allsample}}" _n
file write se "\scalebox{0.9}{" _n
file write se "\begin{adjustbox}{max width=\textwidth}  " _n
file write se "\begin{tabular}{llcccccccc}" _n
file write se "\hline " _n
file write se "\multicolumn{2}{l}{Variable dependiente: Reporte de precios unitarios} \\" 
file write se "\multicolumn{2}{l}{Modelo:}  & [1] & [2]  & [3] & [4] \\ " _n
file write se "\hline" _n

//Coeficientes
local i = 1
 	foreach l in  "Pandemia" "CD: Contratación Directa" " Pandemia x CD" "Constante"{
		file write se "& `l'" 
		
 		foreach j in 1 2 3 4 {
		if reg[`i',`j'] != 0 {
			capture{
			file write se "&"  %5.3f (reg[`i',`j'])
			//Esto pone las estrellas
			if reg[`i'+1,`j']<=0.1{
				file write se "*"  
			}
			if reg[`i'+1,`j']<=0.05{
				file write se "*"  
			}
			if reg[`i'+1,`j']<=0.01{
				file write se "*"  
			}
			}
		} 
		else {
			capture{
				file write se "& - - "
			}
		}
		} 
		file write se "\\" _n	
			//stderr 
			file write se   "&" 
		foreach j in 1 2 3 4 {
		if reg[`i',`j'] != 0 {	
			capture{
				display reg[`i'+2,`j']
				file write se "&"  "(" %5.3f (reg[`i'+2,`j']) ")"
			}
		}
		else {
			capture{
				file write se "& - - "
			}
		}
		}
		file write se "\\" _n	
		local i = `i' +3
	}

	file write se "\hline "_n
	file write se "\multicolumn{2}{l}{Controles de contrato}	"_n
	file write se " & N  & Y  & Y  & Y     \\"_n
	file write se "\multicolumn{2}{l}{Efectos fijos de entidad}	"_n
	file write se " & N  & N  & Y  & Y    \\"_n
	file write se "\multicolumn{2}{l}{Efectos fijos temporales}"_n
	file write se " & N  & N  & N  & Y     \\"_n


	file write se "\multicolumn{2}{l}{Número de observaciones}	&  " %12.0fc (info[1,2]) " &  " %12.0fc (info[2,2])  " & " %12.0fc (info[3,2]) " & " %12.0fc (info[4,2]) "\\" _n
	file write se "\multicolumn{2}{l}{\$R^2$ ajustado }	&  " %12.2fc (info[1,1]*100) " &  " %12.2fc (info[2,1]*100)   " & " %12.2fc (info[3,1]*100)  " & " %12.2fc (info[4,1]*100) "\\" _n
	file write se "\hline "_n
	file write se "\end{tabular}" _n
	file write se "\end{adjustbox}" _n
	file write se "  }  " _n
	file write se "\end{table}" _n
	file write se "\begin{adjustbox}{0.85\textwidth, center} "
	file write se "\begin{minipage}{0.85\textwidth}"
	file write se "\footnotesize" _n
	file write se "\emph{Notas:}  Dependent variable is the unit price of computers deflected by monthly CPI, base Jan 2020. Variables included as contract characteristics were the number of computer purchased and the total contract amount deflected. The supplier characteristic variable was the total contracted amount between the supplier and the organization for each quarter. Standard errors were calculated through a Bayesian Bootstrap with 300 repetitions.  \textit{*p $<$ 0.1, **p $<$ 0.05, *** p$<$ 0.01} " _n
	file write se "\end{minipage}"
	file write se "\end{adjustbox}" _n

	file close se 















































