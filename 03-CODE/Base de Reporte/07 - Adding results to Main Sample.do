//------------------------------------------------------------------------------
//		   00 Compras públicas Peru. Importación y limpieza
//------------------------------------------------------------------------------

//Author: Matias Villalba
//Start Date: 09/04/2023
//Input: Bases de los datos abiertos del OSCE

***********************************************************
**#			0. Set up                             
***********************************************************

* 1. Directories _________________________________________________________
version 17

* Directories
	global root 			"C:\Users\matia\OneDrive - Universidad del Pacífico\01-Medidas_emergencia_PE"
	global data_raw			"$root\01-DATA_PERU\01-DATA_RAW"
	global data_pro 		"$root\01-DATA_PERU\02-DATA_PROCESSED"
	global documentation	"$root\01-DATA_PERU\04-DATA_DOCUMENTATION"
	global output			"$root\01-DATA_PERU\02-DATA_PROCESSED\output"
	

*********************************************************************
**#			1. Limpieza de resultados                             
*********************************************************************

*--------------------------------------------------------------------
**##		Añadimos extraccion a la base principal                  
*--------------------------------------------------------------------
	
use "$data_pro\OSCE_main_sample", clear
	
preserve
import excel using "$data_pro\main_analysis_dfs\pdf_texts.xlsx", firstrow case(lower) clear
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
import excel using "$data_pro\main_analysis_dfs\failed_downloads.xlsx", firstrow case(lower) clear
cap destring n_cod_contrato failed_download, replace
tempfile failed_downloads
save `failed_downloads', replace
restore

merge 1:1 n_cod_contrato using `failed_downloads', nogen
replace failed_download = 0 if failed_download == . 

preserve
import excel using "$data_pro\main_analysis_dfs\broken_pdfs.xlsx", firstrow case(lower) clear
cap destring n_cod_contrato broken_pdf, replace
tempfile broken_pdfs
save `broken_pdfs', replace
restore

merge 1:1 n_cod_contrato using `broken_pdfs', nogen
replace broken_pdf = 0 if broken_pdf == . 

preserve
import excel using "$data_pro\main_analysis_dfs\extraction_df.xlsx", firstrow case(lower) clear
cap destring n_cod_contrato, replace
tempfile extraction_df
save `extraction_df', replace
restore

merge 1:1 n_cod_contrato using `extraction_df', nogen keepusing(gpt_unit_prices)

* Count non-missing items for each observation
ds n_item* 
local varlist `r(varlist)'
egen item_count = rownonmiss(`varlist')

gen unit_price_clean = ustrregexra(gpt_unit_prices, "[^0-9\;\.\,\-]","")
replace unit_price_clean = ustrregexra(unit_price_clean, "\.+",".")
split unit_price_clean, gen(unit_price_) parse(";" "," "-") 
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

use "$data_pro\OSCE_completo_filtrado.dta", clear
sort n_cod_contrato n_item, stable
bysort n_cod_contrato : gen item_group = _n
merge 1:1 n_cod_contrato item_group using `temp', keep(3)

tempfile base_con_error_2021
save `base_con_error_2021', replace

******************************************************************************************************************************************************************************

use "$data_pro\OSCE_2021_main_sample", clear
	
preserve
import excel using "$data_pro\2021_main_analysis_dfs\pdf_texts.xlsx", firstrow case(lower) clear
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
import excel using "$data_pro\2021_main_analysis_dfs\failed_downloads.xlsx", firstrow case(lower) clear
cap destring n_cod_contrato failed_download, replace
tempfile failed_downloads
save `failed_downloads', replace
restore

merge 1:1 n_cod_contrato using `failed_downloads', nogen
replace failed_download = 0 if failed_download == . 

preserve
import excel using "$data_pro\2021_main_analysis_dfs\broken_pdfs.xlsx", firstrow case(lower) clear
cap destring n_cod_contrato broken_pdf, replace
tempfile broken_pdfs
save `broken_pdfs', replace
restore

merge 1:1 n_cod_contrato using `broken_pdfs', nogen
replace broken_pdf = 0 if broken_pdf == . 

preserve
import excel using "$data_pro\2021_main_analysis_dfs\extraction_df.xlsx", firstrow case(lower) clear
cap destring n_cod_contrato, replace
tempfile extraction_df
save `extraction_df', replace
restore

merge 1:1 n_cod_contrato using `extraction_df', nogen keepusing(gpt_unit_prices)

* Count non-missing items for each observation
ds n_item* 
local varlist `r(varlist)'
egen item_count = rownonmiss(`varlist')

gen unit_price_clean = ustrregexra(gpt_unit_prices, "[^0-9\;\.\,\-]","")
replace unit_price_clean = ustrregexra(unit_price_clean, "\.+",".")
split unit_price_clean, gen(unit_price_) parse(";" "," "-") 
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

use "$data_pro\OSCE_2021_filtrado.dta", clear
sort n_cod_contrato n_item, stable
bysort n_cod_contrato : gen item_group = _n
merge 1:1 n_cod_contrato item_group using `temp', keep(3)

tempfile resultados_2021
save `resultados_2021', replace

******************************************************************************************************************************************************************************

use `base_con_error_2021', clear
tempfile labels
label save using `labels', replace
label drop _all
append using `resultados_2021', gen(temp_1)
run `labels'
labellacking _all

duplicates drop

*--------------------------------------------------------------------
**## Creamos control de antiguo proveedor
*--------------------------------------------------------------------

preserve
keep if year_suscripcion == 2018 | year_suscripcion == 2019
collapse (min) fecha_suscripcion_contrato, by(codigoentidad ruc_proveedor) 
rename  fecha_suscripcion_contrato min_fecha_2018_2019
tempfile proveedor_2018_2019
save `proveedor_2018_2019'
restore

merge m:1 codigoentidad ruc_proveedor using `proveedor_2018_2019', gen(merge_2018_2019) keep(1 3)

egen pareja = group(codigoentidad ruc_proveedor)
gen min_fecha = min_fecha_2018_2019 
gen antiguo_proveedor = 0 
replace antiguo_proveedor =  1 if year(fecha_suscripcion_contrato)-year(min_fecha) >=1  & min_fecha!=.

*--------------------------------------------------------------------
**## 	Añadimos codigoclase de CUBSO
*		(diferentes codigos a codigoitem)
*--------------------------------------------------------------------

//añadimos codigos de clase mas generales a partir de cubso para identificar subsectores
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

import excel using "$documentation\Catálogo Único de Bienes, Servicios y Obras (CUBSO)\Cubso al 02.07.2023.xlsx", sheet("SERVICIOS") cellrange(B7) clear
drop if B==""
rename C itemcubso
gen objetocontractual = "Servicio"
gen codigoproducto = substr(B, 1, 8)
gen codigoitem = substr(B, 9, 17)
replace codigoitem = ustrregexra(codigoitem, "^0+", "") //le quitamos los ceros innecesarios al codigo de item
destring codigoitem, replace
append using `codigos_item'
save `codigos_item', replace
restore

merge m:1 codigoitem objetocontractual using `codigos_item', gen(merge_item_2) keep(1 3) keepusing(itemcubso codigoproducto)

gen codigoclase = substr(codigoproducto, 1, 6)
tostring codigoitem, gen(codigoclase2)
replace codigoclase2 = substr(codigoclase2, 1, 4)
destring codigoclase, replace
destring codigoclase2, replace
//Servicios
gen subsector = 1 if inlist(codigoclase, 721214, 851615, 721211, 801315, 721015, 721540, 761115, 721536, 721515, 811123, 731521, 781815, 761015, 721210) //Servicios de alquiler/instalacion/mantenimiento de infraestructura y equipo.

replace subsector = 2 if inlist(codigoclase, 851218, 851015, 701716) // Servicios Medicos Tercerizados.
replace subsector = 3 if inlist(codigoclase, 851017, 801015, 801017, 811017) // Servicios de Consultoria y Asesoramiento.
replace subsector = 4 if inlist(codigoclase, 921015, 911116, 781018, 761220, 811120, 831217, 781118, 771116, 781022, 831115, 831116, 841115, 821016, 821215, 821017, 841316, 841315, 821115, 811118, 931316, 761222) // Otros Servicios Operacionales.

//Bienes
replace subsector = 5 if inlist(substr(strofreal(codigoclase),1,2), "51") // Medicamentos y compuestos medicos.
replace subsector = 5 if inlist(codigoclase, 121419, 123522) // Medicamentos y compuestos medicos
replace subsector = 6 if inlist(codigoclase, 421322, 421426, 421415, 421317, 421425, 422717, 411161, 423115, 422017, 422916, 422722, 421819, 422220, 422951, 423215, 422935, 421616, 421922, 422949, 461815, 421316, 423122, 461820, 411029, 411035, 411158, 421321, 422315, 422719, 422954, 411048, 411049, 422215, 411162, 422846, 411160, 421820) // Equipos, instrumentos y suministros medicos.
replace subsector = 7 if inlist(codigoclase, 422318, 551015, 551218, 151015, 501316, 501927, 141117, 531316, 471318, 501115, 501819, 502211, 101915, 261116, 501515, 501615, 501318, 501317, 501215) //Otros bienes no medicos

label define subsector 1 "Servicios de alquiler, instalacion o mantenimiento/acondicionamiento de infraestructura o equipo" 2 "Servicios Medicos" 3 "Servicios de Consultoria y Asesoramiento" 4 "Otros Servicios Operacionales" 5 "Medicamentos y compuestos médicos"6 "Equipos, instrumentos, utensilios medicos" 7 "Otros bienes no medicos"

label values subsector subsector
*--------------------

gen reporte = (mean_unit_price!=.)

encode codigoentidad, gen(dummyentidad)
encode tipoentidad, gen(dummytipoentidad)
encode sistema_contratacion, gen(dummysistemacontratacion)
encode sector, gen(dummysector)


*--------------------------------------------------------------------
**## 	Eliminamos obs. que no panelizan
*--------------------------------------------------------------------

gen num_contrat = 1 
bys dummyentidad: egen numn_contr_entidad = total(num_contrat)
gen num_contrat_pre = abs(1-d_pandemia)
gen num_contrat_pan = d_pandemia 
bys dummyentidad: egen numn_contr_entidad_prepand = total(num_contrat_pre )
bys dummyentidad: egen numn_contr_entidad_pand = total(num_contrat_pan)
gen panel = numn_contr_entidad_pand > 0 & numn_contr_entidad_prepand > 0
drop numn_contr_entidad num_contrat_pre num_contrat_pan numn_contr_entidad_prepand numn_contr_entidad_pand num_contrat
drop if panel == 0

save "$data_pro\base_para_regresiones", replace

use "$data_pro\base_para_regresiones", clear

*********************************************************************
**#		 2. Regresiones Modelo de Reporte
*********************************************************************

*--------------------------------------------------------------------
**##	 Modelo Completo
*--------------------------------------------------------------------

/////////////////////// Bayesian bootstraping set up
cap drop rw1-rw300
set seed 42
exbsample 300 , stub(rw) //numero de repeticiones 
svyset , bsrweight(rw1-rw300) 

 svy bootstrap : reg reporte i.contratacion##i.d_pandemia
regsave using "$output\regresion_allsample.dta", replace pval autoid  addlabel(model,"1")  detail(scalars)
 svy bootstrap : reg reporte i.contratacion##i.d_pandemia monto_contratado_total i.dummysistemacontratacion antiguo_proveedor
regsave using "$output\regresion_allsample.dta", append pval autoid  addlabel(model,"2")  detail(scalars)
 svy bootstrap : reg reporte i.dummyentidad i.monthyear_suscripcion i.contratacion##i.d_pandemia monto_contratado_total i.dummysistemacontratacion antiguo_proveedor
regsave using "$output\regresion_allsample.dta", append pval autoid  addlabel(model,"3")  detail(scalars)


preserve
use  "$output\regresion_allsample.dta", clear
keep if var=="reporte" |  var =="1.d_pandemia" | var =="1.contratacion" | var =="1.contratacion#1.d_pandemia" | var=="_cons"
gen r2_a =  1- (1-r2)*(N_pop-1)/(N_pop-df_m)

replace var = "1.capandemia" if var=="1.d_pandemia"
replace var = "z_cons " if var=="_cons"

tabstat coef pval stderr if model==1, by(var)  save
mat reg1 = r(Stat1)' \ r(Stat2)' \ r(Stat3)' \ r(Stat4)'
tabstat coef pval stderr if model==2, by(var)  save
mat reg2 = r(Stat1)' \ r(Stat2)' \ r(Stat3)' \ r(Stat4)'
tabstat coef pval stderr if model==3, by(var)  save
mat reg3 = (0, 0, 0)' \ r(Stat1)' \ r(Stat2)' \ r(Stat3)' 
mat reg =  reg1, reg2, reg3
mat list reg 

tabstat r2_a N, by(model) save 
mat info = r(Stat1) \ r(Stat2) \ r(Stat3)




capture: file close se
file open se using "$output\regresion_allsample.tex", write  replace
local max= 6
//Encabezado
file write se  "\linespread{1} " _n
file write se "\begin{table}[H]" _n
file write se "\centering"  _n
file write se "\caption{Regresión modelo de reporte" _n
file write se "\label{tab:regresion_allsample}}" _n
file write se "\scalebox{0.9}{" _n
file write se "\begin{adjustbox}{max width=\textwidth}  " _n
file write se "\begin{tabular}{llccc}" _n
file write se "\hline " _n
file write se "\multicolumn{2}{l}{Variable dependiente: Reporte de precios unitarios} & \multicolumn{3}{c}{Modelo} \\" 
file write se "\multicolumn{2}{l}{}  & [1] & [2] & [3] \\ " _n
file write se "\hline" _n

//Coeficientes
local i = 1
 	foreach l in  "Pandemia" "CD: Contratación Directa" " Pandemia x CD" "Constante"{
		file write se "& `l'" 
		
 		foreach j in 1 2 3 {
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
		foreach j in 1 2 3 {
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
	file write se "\multicolumn{2}{l}{Controles}	"_n
	file write se " & N  & Y  & Y     \\"_n
	file write se "\multicolumn{2}{l}{Efectos fijos de entidad}	"_n
	file write se " & N  & N  & Y    \\"_n
	file write se "\multicolumn{2}{l}{Efectos fijos temporales}"_n
	file write se " & N  & N  & Y     \\"_n


	file write se "\multicolumn{2}{l}{Número de observaciones}	&  " %12.0fc (info[1,2]) " &  " %12.0fc (info[2,2])  " & " %12.0fc (info[3,2]) "\\" _n
	file write se "\multicolumn{2}{l}{\$R^2$ ajustado }	&  " %12.2fc (info[1,1]*100) " &  " %12.2fc (info[2,1]*100)   " & " %12.2fc (info[3,1]*100) "\\" _n
	file write se "\hline "_n
	file write se "\end{tabular}" _n
	file write se "\end{adjustbox}" _n
	file write se "  }  " _n
	file write se "\end{table}" _n
	file write se "\begin{adjustbox}{0.85\textwidth, center} "
	file write se "\begin{minipage}{0.85\textwidth}"
	file write se "\footnotesize" _n
	file write se "\emph{Notas:}  La variable dependiente es una dummy que indica si el precio unitario del item comprado fue reportado en el contrato. Las variables incluídas como controles de contrato fueron el monto total contratado y el sistema de contratación. Los errores estandar fueron calculados a través de un Bootstrap Bayesiano de 300 repeticiones. \textit{*p $<$ 0.1, **p $<$ 0.05, *** p$<$ 0.01} " _n
	file write se "\end{minipage}"
	file write se "\end{adjustbox}" _n

	file close se 

restore

global full_model "i.dummyentidad i.monthyear_suscripcion i.contratacion##i.d_pandemia monto_contratado_total i.dummysistemacontratacion antiguo_proveedor"

*--------------------------------------------------------------------
**##	 Efectos Heterogeneos Bienes y Servicios
*--------------------------------------------------------------------

//Tablas efectos heterogeneos - tipoentidad 
encode objetocontractual, gen(dummyobjeto)

local replace replace 
foreach i in 1 2 {

/////////////////////// Bayesianbootstraping set up
	cap drop rw1-rw300
	set seed 2020
	exbsample 300 , stub(rw) //numero de repeticiones 
	svyset , bsrweight(rw1-rw300) 

	 svy bootstrap : reg reporte ${full_model} if dummyobjeto==`i'
	regsave using "$output\regresion_allsample_het_objetocontractual.dta", `replace' pval autoid  addlabel(model,"`i'")  detail(scalars)
	local replace append
}

preserve
use  "$output\regresion_allsample_het_objetocontractual.dta", clear
keep if var=="reporte" |  var =="1.d_pandemia" | var =="1.contratacion" | var =="1.contratacion#1.d_pandemia" | var=="_cons"
drop if strpos(var,"0b.pandemia#co.")
gen r2_adjusted =  1- (1-r2)*(N_pop-1)/(N_pop-df_m)

//cambios solo para que las variables queden ordenadas 
replace var = "1.capandemia" if var=="1.pandemia"
replace var = "z_cons " if var=="_cons"
// 1nosig 2sig 3omm 4nosig 5nosig 6sig 7omm
tabstat coef pval stderr if model==1, by(var)  save
mat reg1 = r(Stat1)' \ r(Stat2)' \ r(Stat3)' 
tabstat coef pval stderr if model==2, by(var)  save
mat reg2 = r(Stat1)' \ r(Stat2)' \ r(Stat3)' 
mat reg =  reg1, reg2
mat list reg 

tabstat r2_a N, by(model) save 
mat info = r(Stat1) \ r(Stat2)


capture: file close se
file open se using "$output\regresion_allsample_het_objetocontractual.tex", write  replace
local max= 6
//Encabezado
file write se  "\linespread{1} " _n
file write se "\begin{table}[H]" _n
file write se "\centering"  _n
file write se "\caption{Efectos Heterogeneos: Bienes y Servicios" _n 
file write se "\label{tab:regresion_het_obj}}" _n
file write se "\scalebox{0.9}{" _n
file write se "\begin{adjustbox}{max width=\textwidth}  " _n
file write se "\begin{tabular}{llcc}" _n
file write se "\hline " _n
file write se "\multicolumn{2}{l}{Var. dependiente: Reporte} & \multicolumn{2}{c}{Objeto Contractual}  \\" 
file write se "\multicolumn{2}{l}{}  & Bienes & Servicios  \\ " _n
file write se "\hline" _n

//Coeficientes
local i = 1
 	foreach l in   "CD: Contratación Directa" " Pandemia x CD" "Constante"{
		file write se "& `l'" 
		
 		foreach j in 1 2 {
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
		file write se "\\" _n	
			//stderr 
			file write se   "&" 
		foreach j in 1 2 {
			capture{
				display reg[`i'+2,`j']
				file write se "&"  "(" %5.3f (reg[`i'+2,`j']) ")"
			}
		}
		file write se "\\" _n	
		local i = `i' +3
	}

	file write se "\hline "_n
	file write se "\multicolumn{2}{l}{Controles}	"_n
	file write se " & Y  & Y \\"_n
	file write se "\multicolumn{2}{l}{Efectos fijos de entidad}"_n
	file write se " & Y  & Y \\"_n
	file write se "\multicolumn{2}{l}{Efectos fijos temporales}	"_n
	file write se " & Y  & Y \\"_n


	file write se "\multicolumn{2}{l}{Número de observaciones}	&  " %12.0fc (info[1,2]) " &  " %12.0fc (info[2,2])  "\\" _n
	file write se "\multicolumn{2}{l}{\$R^2$ ajustado }	&  " %12.2fc (info[1,1]*100) " &  " %12.2fc (info[2,1]*100)  "\\" _n
	file write se "\hline "_n
	file write se "\end{tabular}" _n
	file write se "\end{adjustbox}" _n
	file write se "  }  " _n
	file write se "\end{table}" _n
	file write se "\begin{adjustbox}{width=0.85\textwidth, center} "
	file write se "\begin{minipage}{0.85\textwidth}"
	file write se "\footnotesize" _n
	file write se "\emph{Notas:}  La variable dependiente es una dummy que indica si el precio unitario del item comprado fue reportado en el contrato. Las variables incluídas como controles de contrato fueron el monto total contratado y el sistema de contratación. El tipo de entidad es tal cual definida como en las bases del OSCE. Los errores estandar fueron calculados a través de un Bootstrap Bayesiano de 300 repeticiones. \textit{*p $<$ 0.1, **p $<$ 0.05, *** p$<$ 0.01}  " _n
	file write se "\end{minipage}"
	file write se "\end{adjustbox}" _n

	file close se 
	
restore

*--------------------------------------------------------------------
**##	 Efectos Heterogeneos Subsector
*--------------------------------------------------------------------

//Tablas efectos heterogeneos - subsector
local replace replace 
forval i = 1/7 {

/////////////////////// Bayesianbootstraping set up
	cap drop rw1-rw300
	set seed 2020
	exbsample 300 , stub(rw) //numero de repeticiones 
	svyset , bsrweight(rw1-rw300) 

	 svy bootstrap : reg reporte ${full_model} if subsector==`i'
	regsave using "$output\regresion_allsample_het_sector.dta", `replace' pval autoid  addlabel(model,"`i'")  detail(scalars)
	local replace append
}

preserve
use  "$output\regresion_allsample_het_sector.dta", clear
keep if var=="reporte" |  var =="1.d_pandemia" | var =="1.contratacion" | var =="1.contratacion#1.d_pandemia" | var=="_cons"
drop if strpos(var,"0b.pandemia#co.")
gen r2_adjusted =  1- (1-r2)*(N_pop-1)/(N_pop-df_m)

//cambios solo para que las variables queden ordenadas 
replace var = "1.capandemia" if var=="1.pandemia"
replace var = "z_cons " if var=="_cons"


tabstat coef pval stderr if model==1, by(var)  save // Servicios de mantenimiento
mat reg1 = r(Stat1)' \ r(Stat2)' \ r(Stat3)' 
tabstat coef pval stderr if model==2, by(var)  save // Servicios Medicos
mat reg2 = r(Stat1)' \ r(Stat2)' \ r(Stat3)' 
tabstat coef pval stderr if model==5, by(var)  save // Medicamentos
mat reg3 = r(Stat1)' \ r(Stat2)' \ r(Stat3)' 
tabstat coef pval stderr if model==6, by(var)  save // Equipos e instrumentos medicos
mat reg4 = r(Stat1)' \ r(Stat2)' \ r(Stat3)' 
mat reg =  reg1, reg2, reg3, reg4
mat list reg 

tabstat r2_a N, by(model) save 
mat info = r(Stat1) \ r(Stat2) \ r(Stat5) \ r(Stat6) 


capture: file close se
file open se using "$output\regresion_allsample_het_sector.tex", write  replace
local max= 6
//Encabezado
file write se  "\linespread{1} " _n
file write se "\begin{table}[H]" _n
file write se "\centering"  _n
file write se "\caption{Efectos Heterogeneos: Subsector" _n 
file write se "\label{tab:regresion_het_subsector}}" _n
file write se "\scalebox{0.9}{" _n
file write se "\begin{adjustbox}{max width=\textwidth}  " _n
file write se "\begin{tabular}{llcccc}" _n
file write se "\hline " _n
file write se "\multicolumn{2}{l}{Var. Dependiente: Reporte} & \multicolumn{2}{c}{Sevicios} & \multicolumn{2}{c}{Bienes}  \\" _n
file write se " & & Mantenimiento & Médicos & Medicamentos & Utensilios \\ " _n
file write se "\hline" _n

//Coeficientes
local i = 1
 	foreach l in   "CD: Contratación Directa" " Pandemia x CD" "Constante"{
		file write se "& `l'" 
		
 		foreach j in 1 2 3 4 {
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
		file write se "\\" _n	
			//stderr 
			file write se   "&" 
		foreach j in 1 2 3 4 {
			capture{
				display reg[`i'+2,`j']
				file write se "&"  "(" %5.3f (reg[`i'+2,`j']) ")"
			}
		}
		file write se "\\" _n	
		local i = `i' +3
	}

	file write se "\hline "_n
	file write se "\multicolumn{2}{l}{Controles de contrato}	"_n
	file write se " & Y  & Y  & Y  & Y   \\"_n
	file write se "\multicolumn{2}{l}{Efectos fijos de entidad}"_n
	file write se " & Y  & Y  & Y  & Y    \\"_n
	file write se "\multicolumn{2}{l}{Efectos fijos temporales}	"_n
	file write se " & Y  & Y  & Y  & Y  \\"_n


	file write se "\multicolumn{2}{l}{Número de observaciones}	&  " %12.0fc (info[1,2]) " &  " %12.0fc (info[2,2])  " & " %12.0fc (info[3,2]) " & " %12.0fc (info[4,2]) "\\" _n
	file write se "\multicolumn{2}{l}{\$R^2$ ajustado }	&  " %12.2fc (info[1,1]*100) " &  " %12.2fc (info[2,1]*100)   " & " %12.2fc (info[3,1]*100) " & " %12.2fc (info[4,1]*100) "\\" _n
	file write se "\hline "_n
	file write se "\end{tabular}" _n
	file write se "\end{adjustbox}" _n
	file write se "  }  " _n
	file write se "\end{table}" _n
	file write se "\begin{adjustbox}{width=0.85\textwidth, center} "
	file write se "\begin{minipage}{0.85\textwidth}"
	file write se "\footnotesize" _n
	file write se "\emph{Notas:}  La variable dependiente es una dummy que indica si el precio unitario del item comprado fue reportado en el contrato. Las variables incluídas como controles de contrato fueron el monto total contratado y el sistema de contratación. La categoria de sector es tal cual definida como en las bases del OSCE. Los errores estandar fueron calculados a través de un Bootstrap Bayesiano de 300 repeticiones. \textit{*p $<$ 0.1, **p $<$ 0.05, *** p$<$ 0.01}  " _n
	file write se "\end{minipage}"
	file write se "\end{adjustbox}" _n

	file close se 
	
restore

*********************************************************************
**# 	3. Pruebas de robustes
*********************************************************************

preserve

*--------------------------------------------------------------------
**## Prueba de falsificación
*--------------------------------------------------------------------

keep if d_pandemia ==0 //Nos quedamos con el periodo pre-tratamiento para probar parallel trends

local replace replace
forval i = 708/718 { //iteramos para cada mes de la muestra
di "`i'"
	
gen d_test = monthyear_suscripcion>`i' //generamos el simil de d_pandemia pero dentro del periodo pre-tratamiento

reg reporte i.dummyentidad i.monthyear_suscripcion monto_contratado_total i.dummysistemacontratacion i.contratacion##i.d_test 
regsave using "$output\regresion_falsification_reporte.dta", `replace' pval autoid  addlabel(model,"`i'")  detail(scalars)
local replace append
drop d_test
}

use  "$output\regresion_falsification_reporte.dta", clear
keep if var =="1.contratacion#1.d_test"

//cambios solo para que las variables queden ordenadas 
replace var = "1.capandemia" if var=="1.pandemia"
replace var = "z_cons " if var=="_cons"

tabstat coef pval stderr if model==708, by(var)  save // Servicios de mantenimiento
mat reg1 = r(Stat1)' \ r(Stat2)' \ r(Stat3)' 
tabstat coef pval stderr if model==709, by(var)  save // Servicios Medicos
mat reg2 = r(Stat1)' \ r(Stat2)' \ r(Stat3)' 
tabstat coef pval stderr if model==710, by(var)  save // Medicamentos
mat reg3 = r(Stat1)' \ r(Stat2)' \ r(Stat3)' 
tabstat coef pval stderr if model==711, by(var)  save // Equipos e instrumentos medicos
mat reg4 = r(Stat1)' \ r(Stat2)' \ r(Stat3)' 
tabstat coef pval stderr if model==712, by(var)  save // Servicios de mantenimiento
mat reg5 = r(Stat1)' \ r(Stat2)' \ r(Stat3)' 
tabstat coef pval stderr if model==713, by(var)  save // Servicios Medicos
mat reg6 = r(Stat1)' \ r(Stat2)' \ r(Stat3)' 
tabstat coef pval stderr if model==714, by(var)  save // Medicamentos
mat reg7 = r(Stat1)' \ r(Stat2)' \ r(Stat3)' 
tabstat coef pval stderr if model==715, by(var)  save // Equipos e instrumentos medicos
mat reg8 = r(Stat1)' \ r(Stat2)' \ r(Stat3)' 
tabstat coef pval stderr if model==716, by(var)  save // Servicios de mantenimiento
mat reg9 = r(Stat1)' \ r(Stat2)' \ r(Stat3)' 
tabstat coef pval stderr if model==717, by(var)  save // Servicios Medicos
mat reg10 = r(Stat1)' \ r(Stat2)' \ r(Stat3)' 
tabstat coef pval stderr if model==718, by(var)  save // Medicamentos
mat reg11 = r(Stat1)' \ r(Stat2)' \ r(Stat3)' 
mat reg =  reg1, reg2, reg3, reg4, reg5, reg6, reg7, reg8, reg9, reg10, reg11
mat list reg 

tabstat r2_a N, by(model) save 
mat info = r(Stat1) \ r(Stat2) \ r(Stat5) \ r(Stat6) 

 
capture: file close se
file open se using "$output\regresion_falsification_reporte.tex", write  replace
local max= 6
//Encabezado
file write se  "\linespread{1} " _n
file write se "\begin{table}[H]" _n
file write se "\centering"  _n
file write se "\caption{Prueba de falsificación" _n 
file write se "\label{tab:regresion_falsification_reporte}}" _n
file write se "\scalebox{0.9}{" _n
file write se "\begin{adjustbox}{max width=\textwidth}  " _n
file write se "\begin{tabular}{llcccc}" _n
file write se "\hline " _n
file write se "\multicolumn{2}{l}{Var. Dependiente: Reporte} & \multirow{2}{*}{Coeficiente} & \multirow{2}{*}{P-Value}  \\" _n
file write se " & Esp. de dummy temporal (quiebre) & & \\ " _n
file write se "\hline" _n

//Coeficientes
local j = 1
 	foreach l in  "[1] Ene 2019" "[2] Feb 2019" "[3] Mar 2019" "[4] Abr 2019" "[5] May 2019" "[6] Jun 2019" "[7] Jul 2019" "[8] Ago 2019" "[9] Sep 2019" "[10] Oct 2019" "[11] Nov 2019" {
		file write se "& \multirow{2}{*}{`l'}" 
		
 		foreach i in 1 {
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
			
			file write se "& \multirow{2}{*}{" %5.4f (reg[`i'+1,`j']) "}"
			
		}
		file write se "\\" _n	
			//stderr 
			file write se   "&" 
		foreach i in 1 {
			capture{
				display reg[`i'+2,`j']
				file write se "&"  "(" %5.3f (reg[`i'+2,`j']) ") & "
			}
		}
		file write se "\\" _n
		local j = `j' +1
	}

	file write se "\hline "_n
	file write se "\multicolumn{2}{l}{Controles de contrato}	"_n
	file write se " & Y & --   \\"_n
	file write se "\multicolumn{2}{l}{Efectos fijos de entidad}"_n
	file write se " & Y & --    \\"_n
	file write se "\multicolumn{2}{l}{Efectos fijos temporales}	"_n
	file write se " & Y & -- \\"_n

	file write se "\multicolumn{2}{l}{Número de observaciones}	&  " %12.0fc (info[1,2]) "& -- \\" _n
	file write se "\multicolumn{2}{l}{\$R^2$ ajustado }	&  " %12.2fc (info[1,1]*100) "& -- \\" _n
	file write se "\hline "_n
	file write se "\end{tabular}" _n
	file write se "\end{adjustbox}" _n
	file write se "  }  " _n
	file write se "\end{table}" _n
	file write se "\begin{adjustbox}{width=0.85\textwidth, center} "
	file write se "\begin{minipage}{0.85\textwidth}"
	file write se "\footnotesize" _n
	file write se "\emph{Notas:} Esta tabla resalta la insignificancia del termino de interés (la interacción entre la dummy temporal y contratacion directa) para cualquier especificación de la dummy temporal durante el periodo pre-tratamiento (cada fila corresponde una regresión con diferente especificación de dicha variable, que en el modelo principal llamamos Pandemia), quiere decir que durante el pre-tratamiento no hubieron efectos diferenciados entre contratos competitivos y directos. \textit{*p $<$ 0.1, **p $<$ 0.05, *** p$<$ 0.01}  " _n
	file write se "\end{minipage}"
	file write se "\end{adjustbox}" _n

	file close se 

restore

preserve

*--------------------------------------------------------------------
**## Prueba de tendencias paralelas
*--------------------------------------------------------------------

*keep if d_pandemia ==0 //Nos quedamos con el periodo pre-tratamiento para probar parallel trends
	
reg reporte i.dummyentidad i.monthyear_suscripcion monto_contratado_total i.dummysistemacontratacion i.contratacion##i.quarteryear_suscripcion 
regsave using "$output\regresion_parallel_reporte.dta", replace pval autoid  addlabel(model,"1")  detail(scalars)
//Corremos el modelo con esta especificacion, en teoria si se cumplese parallel trends la interaccion entre contratacion y las dummies de quarteryear tendrian que ser no significativas


use  "$output\regresion_parallel_reporte.dta", clear
keep if regexm(var, "1.contratacion#23[0-9].quarteryear_suscripcion")
drop if strpos(var,"0b.pandemia#co.")


tabstat coef pval stderr if model==1, by(var)  save // Servicios de mantenimiento
mat reg1 = r(Stat1)' \ r(Stat2)' \ r(Stat3)' \ r(Stat4)' \ r(Stat5)' \ r(Stat6)' \ r(Stat7)' 
mat reg =  reg1
mat list reg 

tabstat r2_a N, by(model) save 
mat info = r(Stat1) 
mat list info


capture: file close se
file open se using "$output\regresion_parallel_reporte.tex", write  replace
local max= 6
//Encabezado
file write se  "\linespread{1} " _n
file write se "\begin{table}[H]" _n
file write se "\centering"  _n
file write se "\caption{Prueba de tendencias paralelas" _n 
file write se "\label{tab:regresion_parallel_reporte}}" _n
file write se "\scalebox{0.9}{" _n
file write se "\begin{adjustbox}{max width=\textwidth}  " _n
file write se "\begin{tabular}{llc}" _n
file write se "\hline " _n
file write se "\multicolumn{2}{l}{Var. Dependiente: Reporte} & Modelo \\" _n
file write se " & & [1] \\ " _n
file write se "\hline" _n

//Coeficientes
local i = 1
 	foreach l in   "2018Q2 x CD" "2018Q3 x CD" "2018Q4 x CD" "2019Q1 x CD" "2019Q2 x CD" "2019Q3 x CD" "2019Q4 x CD" {
		file write se "& `l'" 
		
 		foreach j in 1 {
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
		file write se "\\" _n	
			//stderr 
			file write se   "&" 
		foreach j in 1 {
			capture{
				display reg[`i'+2,`j']
				file write se "&"  "(" %5.3f (reg[`i'+2,`j']) ")"
			}
		}
		file write se "\\" _n	
		local i = `i' +3
	}

	file write se "\hline "_n
	file write se "\multicolumn{2}{l}{Controles de contrato}	"_n
	file write se " & Y  \\"_n
	file write se "\multicolumn{2}{l}{Efectos fijos de entidad}"_n
	file write se " & Y  \\"_n
	file write se "\multicolumn{2}{l}{Efectos fijos temporales}	"_n
	file write se " & Y  \\"_n


	file write se "\multicolumn{2}{l}{Número de observaciones}	&  " %12.0fc (info[1,2]) "\\" _n
	file write se "\multicolumn{2}{l}{\$R^2$ ajustado }	&  " %12.2fc (info[1,1]*100) "\\" _n
	file write se "\hline "_n
	file write se "\end{tabular}" _n
	file write se "\end{adjustbox}" _n
	file write se "  }  " _n
	file write se "\end{table}" _n
	file write se "\begin{adjustbox}{width=0.85\textwidth, center} "
	file write se "\begin{minipage}{0.85\textwidth}"
	file write se "\footnotesize" _n
	file write se "\emph{Notas:}  Esta tabla resalta la insignificancia de los . \textit{*p $<$ 0.1, **p $<$ 0.05, *** p$<$ 0.01}   " _n
	file write se "\end{minipage}"
	file write se "\end{adjustbox}" _n

	file close se 
	






restore

*********************************************************************
**# 	4. Regresiones Modelo Precios Unitarios
*********************************************************************
preserve

keep if reporte == 1
keep if objetocontractual == "Bien"
gen ratio = mean_unit_price/monto_contratado_item
drop if ratio > 0.85
gen ratio2 = mean_unit_price/monto_contratado_total
drop if ratio2 > 0.85

*--------------------------------------------------------------------
**## 	Eliminamos obs. que no panelizan
*--------------------------------------------------------------------

gen num_item = 1 
bys codigoitem: egen numn_contr_item = total(num_item)
gen num_contrat_pre = abs(1-d_pandemia)
gen num_contrat_pan = d_pandemia 
bys codigoitem: egen numn_contr_codigoitem_prepand = total(num_contrat_pre)
bys codigoitem: egen numn_contr_codigoitem_pand = total(num_contrat_pan)
gen panel_item = numn_contr_codigoitem_pand > 0 & numn_contr_codigoitem_prepand > 0
drop numn_contr_item num_contrat_pre num_contrat_pan numn_contr_codigoitem_prepand numn_contr_codigoitem_pand num_item
drop if panel_item == 0



/////////////////////// Bayesian bootstraping set up
cap drop rw1-rw300
set seed 42
exbsample 300 , stub(rw) //numero de repeticiones 
svyset , bsrweight(rw1-rw300) 



svy bootstrap : reg mean_unit_price i.codigoitem i.contratacion##i.d_pandemia
regsave using "$output\regresion_allsample_prices.dta", replace pval autoid  addlabel(model,"1")  detail(scalars)
 svy bootstrap : reg mean_unit_price monto_contratado_total i.dummysistemacontratacion i.codigoitem antiguo_proveedor i.contratacion##i.d_pandemia
regsave using "$output\regresion_allsample_prices.dta", append pval autoid  addlabel(model,"2")  detail(scalars)
 svy bootstrap : reg mean_unit_price i.dummyentidad i.monthyear_suscripcion monto_contratado_total i.dummysistemacontratacion i.codigoitem antiguo_proveedor i.contratacion##i.d_pandemia
regsave using "$output\regresion_allsample_prices.dta", append pval autoid  addlabel(model,"3")  detail(scalars)



use  "$output\regresion_allsample_prices.dta", clear
keep if var=="mean_unit_price" |  var =="1.d_pandemia" | var =="1.contratacion" | var =="1.contratacion#1.d_pandemia" | var=="_cons"
gen r2_a =  1- (1-r2)*(N_pop-1)/(N_pop-df_m)

replace var = "1.capandemia" if var=="1.d_pandemia"
replace var = "z_cons " if var=="_cons"

tabstat coef pval stderr if model==1, by(var)  save
mat reg1 = r(Stat1)' \ r(Stat2)' \ r(Stat3)' \ r(Stat4)'
tabstat coef pval stderr if model==2, by(var)  save
mat reg2 = r(Stat1)' \ r(Stat2)' \ r(Stat3)' \ r(Stat4)'
tabstat coef pval stderr if model==3, by(var)  save
mat reg3 = (0, 0, 0)' \ r(Stat1)' \ r(Stat2)' \ r(Stat3)' 
mat reg =  reg1, reg2, reg3
mat list reg 

tabstat r2_a N, by(model) save 
mat info = r(Stat1) \ r(Stat2) \ r(Stat3)




capture: file close se
file open se using "$output\regresion_allsample_prices.tex", write  replace
local max= 6
//Encabezado
file write se  "\linespread{1} " _n
file write se "\begin{table}[H]" _n
file write se "\centering"  _n
file write se "\caption{Regresión modelo de precios unitarios" _n
file write se "\label{tab:regresion_allsample_prices}}" _n
file write se "\scalebox{0.9}{" _n
file write se "\begin{adjustbox}{max width=\textwidth}  " _n
file write se "\begin{tabular}{llccc}" _n
file write se "\hline " _n
file write se "\multicolumn{2}{l}{Variable dependiente: precios unitarios} & \multicolumn{3}{c}{Modelo} \\" 
file write se "\multicolumn{2}{l}{}  & [1] & [2] & [3] \\ " _n
file write se "\hline" _n

//Coeficientes
local i = 1
 	foreach l in  "Pandemia" "CD: Contratación Directa" " Pandemia x CD" "Constante"{
		file write se "& `l'" 
		
 		foreach j in 1 2 3 {
		if reg[`i',`j'] != 0 {
			capture{
			file write se "&"  %9.2f (reg[`i',`j'])
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
		foreach j in 1 2 3 {
		if reg[`i',`j'] != 0 {	
			capture{
				display strlen(string(floor(reg[`i'+2,`j'])))
				if strlen(string(floor(reg[`i'+2,`j'])))==2 { 
					file write se "&"  "(" %4.2f (reg[`i'+2,`j']) ")" 
				} 
				if strlen(string(floor(reg[`i'+2,`j'])))==3 {
					file write se "&"  "(" %5.2f (reg[`i'+2,`j']) ")" 	
				}
				if strlen(string(floor(reg[`i'+2,`j'])))==4 {
					file write se "&"  "(" %7.2f (reg[`i'+2,`j']) ")"
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
		local i = `i' +3
	}

	file write se "\hline "_n
	file write se "\multicolumn{2}{l}{Control de producto}	"_n
	file write se " & Y  & Y  & Y     \\"_n
	file write se "\multicolumn{2}{l}{Controles}	"_n
	file write se " & N  & Y  & Y     \\"_n
	file write se "\multicolumn{2}{l}{Efectos fijos de entidad}	"_n
	file write se " & N  & N  & Y    \\"_n
	file write se "\multicolumn{2}{l}{Efectos fijos temporales}"_n
	file write se " & N  & N  & Y     \\"_n


	file write se "\multicolumn{2}{l}{Número de observaciones}	&  " %12.0fc (info[1,2]) " &  " %12.0fc (info[2,2])  " & " %12.0fc (info[3,2]) "\\" _n
	file write se "\multicolumn{2}{l}{\$R^2$ ajustado }	&  " %12.2fc (info[1,1]*100) " &  " %12.2fc (info[2,1]*100)   " & " %12.2fc (info[3,1]*100) "\\" _n
	file write se "\hline "_n
	file write se "\end{tabular}" _n
	file write se "\end{adjustbox}" _n
	file write se "  }  " _n
	file write se "\end{table}" _n
	file write se "\begin{adjustbox}{0.85\textwidth, center} "
	file write se "\begin{minipage}{0.85\textwidth}"
	file write se "\footnotesize" _n
	file write se "\emph{Notas:}  La variable dependiente es el precio unitario del item comprado. Siempre se controla por item para superar problemas de agregacion. Las variables incluídas como controles de contrato fueron el monto total contratado y el sistema de contratación. Los errores estandar fueron calculados a través de un Bootstrap Bayesiano de 300 repeticiones. \textit{*p $<$ 0.1, **p $<$ 0.05, *** p$<$ 0.01} " _n
	file write se "\end{minipage}"
	file write se "\end{adjustbox}" _n

	file close se 
	
	

restore




*********************************************************************
**# 	5. Pruebas de robustes
*********************************************************************

preserve

keep if reporte == 1
keep if objetocontractual == "Bien"
gen ratio = mean_unit_price/monto_contratado_item
drop if ratio > 0.85
gen ratio2 = mean_unit_price/monto_contratado_total
drop if ratio2 > 0.85

gen num_item = 1 
bys codigoitem: egen numn_contr_item = total(num_item)
gen num_contrat_pre = abs(1-d_pandemia)
gen num_contrat_pan = d_pandemia 
bys codigoitem: egen numn_contr_codigoitem_prepand = total(num_contrat_pre)
bys codigoitem: egen numn_contr_codigoitem_pand = total(num_contrat_pan)
gen panel_item = numn_contr_codigoitem_pand > 0 & numn_contr_codigoitem_prepand > 0
drop numn_contr_item num_contrat_pre num_contrat_pan numn_contr_codigoitem_prepand numn_contr_codigoitem_pand num_item
drop if panel_item == 0

*--------------------------------------------------------------------
**## Prueba de tendencias paralelas
*--------------------------------------------------------------------
	
reg mean_unit_price i.codigoitem i.dummyentidad i.contratacion##i.quarteryear_suscripcion 
regsave using "$output\regresion_parallel_unit_price.dta", replace pval autoid  addlabel(model,"1")  detail(scalars)
//Corremos el modelo con esta especificacion, en teoria si se cumplese parallel trends la interaccion entre contratacion y las dummies de quarteryear tendrian que ser no significativas



use  "$output\regresion_parallel_unit_price.dta", clear
keep if regexm(var, "1.contratacion#23[0-9].quarteryear_suscripcion")
drop if strpos(var,"0b.pandemia#co.")


tabstat coef pval stderr if model==1, by(var)  save
mat reg1 = r(Stat1)' \ r(Stat2)' \ r(Stat3)' \ r(Stat4)' \ r(Stat5)'
mat reg =  reg1
mat list reg 

tabstat r2_a N, by(model) save 
mat info = r(Stat1) 
mat list info


capture: file close se
file open se using "$output\regresion_parallel_unit_price.tex", write  replace
local max= 6
//Encabezado
file write se  "\linespread{1} " _n
file write se "\begin{table}[H]" _n
file write se "\centering"  _n
file write se "\caption{Prueba de tendencias paralelas" _n 
file write se "\label{tab:regresion_parallel_unit_price}}" _n
file write se "\scalebox{0.9}{" _n
file write se "\begin{adjustbox}{max width=\textwidth}  " _n
file write se "\begin{tabular}{llc}" _n
file write se "\hline " _n
file write se "\multicolumn{2}{l}{Var. Dependiente: Precio Unitario} & Modelo \\" _n
file write se " & & [1] \\ " _n
file write se "\hline" _n

//Coeficientes
local i = 1
 	foreach l in   "2018Q2 x CD" "2018Q3 x CD" "2018Q4 x CD" "2019Q1 x CD" "2019Q3 x CD" {
		file write se "& `l'" 
		
 		foreach j in 1 {
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
		file write se "\\" _n	
			//stderr 
			file write se   "&" 
		foreach j in 1 {
			capture{
				display reg[`i'+2,`j']
				file write se "&"  "(" %5.3f (reg[`i'+2,`j']) ")"
			}
		}
		file write se "\\" _n	
		local i = `i' +3
	}

	file write se "\hline "_n
	file write se "\multicolumn{2}{l}{Controles de producto}	"_n
	file write se " & Y  \\"_n
	file write se "\multicolumn{2}{l}{Controles de contrato}	"_n
	file write se " & N  \\"_n
	file write se "\multicolumn{2}{l}{Efectos fijos de entidad}"_n
	file write se " & Y  \\"_n
	file write se "\multicolumn{2}{l}{Efectos fijos temporales}	"_n
	file write se " & Y  \\"_n


	file write se "\multicolumn{2}{l}{Número de observaciones}	&  " %12.0fc (info[1,2]) "\\" _n
	file write se "\multicolumn{2}{l}{\$R^2$ ajustado }	&  " %12.2fc (info[1,1]*100) "\\" _n
	file write se "\hline "_n
	file write se "\end{tabular}" _n
	file write se "\end{adjustbox}" _n
	file write se "  }  " _n
	file write se "\end{table}" _n
	file write se "\begin{adjustbox}{width=0.85\textwidth, center} "
	file write se "\begin{minipage}{0.85\textwidth}"
	file write se "\footnotesize" _n
	file write se "\emph{Notas:}  Esta tabla resalta la insignificancia de los . \textit{*p $<$ 0.1, **p $<$ 0.05, *** p$<$ 0.01}   " _n
	file write se "\end{minipage}"
	file write se "\end{adjustbox}" _n

	file close se 

restore


*********************************************************************
**# 	6. Evolucion descriptivas
*********************************************************************
use "$data_pro\base_para_regresiones", clear

gen grupos_contratacion = 1 if tipoprocesoseleccion == "Contratación Directa" 
replace  grupos_contratacion = 2 if tipoprocesoseleccion == "Concurso Público" | tipoprocesoseleccion == "Licitación Pública" // Auctions
replace  grupos_contratacion = 3 if tipoprocesoseleccion == "Adjudicación Simplificada" | tipoprocesoseleccion == "Adjudicación Simplificada-Homologación" | tipoprocesoseleccion == "Comparación de Precios"
replace  grupos_contratacion = 4 if tipoprocesoseleccion == "Convenio" | tipoprocesoseleccion == "Contratación Internacional" | tipoprocesoseleccion == "Subasta Inversa Electrónica"
drop if grupos_contratacion==.

label define grupos_contratacion 1 "Direct deal" 2 "Licitación Publica" 3 "Adjudicación Simplificada" 4 "Subasta Inversa Electronica"
label values grupos_contratacion grupos_contratacion


* Generating a counter
cap drop num_contratos
gen num_contratos=1
sort n_cod_contrato n_item, stable
replace num_contratos=0 if n_cod_contrato[_n-1]==n_cod_contrato[_n]

keep num_contratos year_suscripcion grupos_contratacion
collapse (sum) num_contratos, by(year_suscripcion grupos_contratacion)

reshape wide num_contratos, i(year_suscripcion) j(grupos_contratacion)
gsort year_suscripcion

tsset year_suscripcion 

gen total_contratos= num_contratos1+num_contratos2+num_contratos3+num_contratos4
forval i = 1/4{
gen share`i' = num_contratos`i'/total_contratos
}


tsline share1 share2 share3 share4, graphregion(fcolor(white) lwidth(large)) xtit("Año") ytit("Porcentaje de contratos") lcolor(maroon ebblue eltblue emidblue) ttext(0.55 2019.9 "Pandemia", orient(vert) box bcolor(white) fcolor(white)) tline(2020, lcolor(gs11)) ///
ms(O square T D) mcolor(maroon ebblue eltblue emidblue) recast(connected) ///
legend(order(1 "Contratación Directa" 2 "Licitación Publica" 3 "Adjudicación Simplificada" 4 "Subasta Inversa Electronica")) name(share_contracts, replace)
graph export "$output\evolution_share_contracts.png" , width(1000) height(600) replace

tsline num_contratos1 num_contratos2 num_contratos3 num_contratos4, graphregion(fcolor(white) lwidth(large)) xtit("Año") ytit("Numero de contratos") lcolor(maroon ebblue eltblue emidblue) ttext(500 2019.9 "Pandemia", orient(vert) box bcolor(white) fcolor(white)) tline(2020, lcolor(gs11)) ///
ms(O square T D) mcolor(maroon ebblue eltblue emidblue) recast(connected) ///
legend(order(1 "Contratación Directa" 2 "Licitación Publica" 3 "Adjudicación Simplificada" 4 "Subasta Inversa Electronica")) name(num_contracts, replace)
graph export "$output\evolution_num_contracts.png" , width(1000) height(600) replace

grc1leg num_contracts share_contracts, c(2) scale(1.4) legendfrom(num_contracts) name(evol_descriptives, replace)

graph display evol_descriptives, xsize(11) ysize(4)
graph export "$output\evolution_descriptives.png" , width(11000) height(4000) replace

*********************************************************************************
use "$data_pro\base_para_regresiones", clear

keep if reporte == 1
keep if objetocontractual == "Bien"
gen ratio = mean_unit_price/monto_contratado_item
drop if ratio > 0.85
gen ratio2 = mean_unit_price/monto_contratado_total
drop if ratio2 > 0.85

*--------------------------------------------------------------------
*	Eliminamos obs. que no panelizan
*--------------------------------------------------------------------

gen num_item = 1 
bys codigoitem: egen numn_contr_item = total(num_item)
gen num_contrat_pre = abs(1-d_pandemia)
gen num_contrat_pan = d_pandemia 
bys codigoitem: egen numn_contr_codigoitem_prepand = total(num_contrat_pre)
bys codigoitem: egen numn_contr_codigoitem_pand = total(num_contrat_pan)
gen panel_item = numn_contr_codigoitem_pand > 0 & numn_contr_codigoitem_prepand > 0
drop numn_contr_item num_contrat_pre num_contrat_pan numn_contr_codigoitem_prepand numn_contr_codigoitem_pand num_item
drop if panel_item == 0


keep mean_unit_price year_suscripcion contratacion
collapse (mean) mean_unit_price, by(year_suscripcion contratacion)

reshape wide mean_unit_price, i(year_suscripcion) j(contratacion)
gsort year_suscripcion

tsset year_suscripcion 

tsline mean_unit_price0 mean_unit_price1, graphregion(fcolor(white) lwidth(large)) xtit("Year") ytit("Mean Unit Price") lcolor(maroon ebblue) ttext(3600 2019.9 "Pandemic", orient(vert) box bcolor(white) fcolor(white)) tline(2020, lcolor(gs11)) ///
ms(O square T X) mcolor(maroon ebblue) recast(connected) ///
legend(order(1 "Other procedures" 2 "Direct Deal"))
graph export "$output\evolution_share_contracts.png" , width(1000) height(600) replace

*********************************************************************************
use "$data_pro\base_para_regresiones", clear

keep reporte year_suscripcion contratacion year_suscripcion
collapse (mean) reporte, by(year_suscripcion contratacion year_suscripcion)

reshape wide reporte, i(year_suscripcion) j(contratacion)
gsort year_suscripcion

tsset year_suscripcion 

twoway tsline reporte0 reporte1, graphregion(fcolor(white) lwidth(large)) xtit("Year") ytit("Mean Unit Price") lcolor(maroon ebblue) ttext(3600 2019.9 "Pandemic", orient(vert) box bcolor(white) fcolor(white)) tline(2020, lcolor(gs11)) ///
ms(O square T X) mcolor(maroon ebblue) recast(connected) ///
legend(order(1 "Other procedures" 2 "Direct Deal"))
graph export "$output\evolution_share_contracts.png" , width(1000) height(600) replace













