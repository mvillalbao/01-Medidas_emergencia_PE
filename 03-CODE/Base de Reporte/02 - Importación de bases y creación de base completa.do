//------------------------------------------------------------------------------
//		   00 Compras públicas Peru. Importación y limpieza
//------------------------------------------------------------------------------

//Author: Matias Villalba
//Start Date: 09/04/2023
//Version: 04/03/2024
//Input: Bases de los datos abiertos del OSCE

//requires: gtools, labutil

***********************************************************
*	0.          Set up                             
***********************************************************

* 1. Directories _________________________________________________________
version 17

* Directories
	global root 			"D:\01-Medidas_emergencia_PE_2024"
	global data_raw			"$root\01-DATA_RAW"
	global data_pro 		"$root\02-DATA_PROCESSED\"
	global documentation	"$root\04-DATA_DOCUMENTATION\"


*******************************************************************
**# BASE DE CONVOCATORIAS
*******************************************************************

clear

tempfile OSCE_convocatoria
save `OSCE_convocatoria', emptyok

// Unificamos los archivos anuales de la base de convocatorias

forval i = 2018/2023{
	import excel using "$data_raw\scraped_files\DATOS_DE_CONVOCATORIA\conosceconvocatorias`i'.xlsx", cellrange(A2) firstrow case(lower) clear
	if _N != 0 {
		append using `OSCE_convocatoria'
		save `OSCE_convocatoria', replace
	}
}

/*preserve
include "$documentation\Descripcion_de_las_bases\Desc_var.do"
quietly export excel varname varlabel using "$documentation\Descripcion_de_las_bases\Descripción_bases.xlsx", sheet("OSCE_convocatoria") firstrow(variables) sheetreplace
restore*/

gen year_convocatoria = year(fecha_convocatoria)
gen month_convocatoria =  month(fecha_convocatoria)

//IDS: codigoconvocatoria n_item
duplicates drop codigoconvocatoria n_item, force //un item es asumido como error de registro
gisid codigoconvocatoria n_item

save "$data_pro\OSCE_convocatoria", replace


*******************************************************************
**# BASE DE CONTRATOS
*******************************************************************

clear

tempfile OSCE_contratos
save `OSCE_contratos', emptyok

// Unificamos los archivos anuales de la base de contratos

forval i = 2018/2023{ 
	import excel using "$data_raw\scraped_files\DATOS_DE_CONTRATOS\conoscecontratos`i'.xlsx", cellrange(A2) firstrow case(lower) clear
	if _N != 0 {
		append using `OSCE_contratos'
		save `OSCE_contratos', replace
	}
}

/*preserve
include "$documentation\Descripcion_de_las_bases\Desc_var.do"
quietly export excel varname varlabel using "$documentation\Descripcion_de_las_bases\Descripción_bases.xlsx", sheet("OSCE_contratos") firstrow(variables) sheetreplace
restore*/

// Reemplazamos missings por 0 en las variable monetarias
foreach x in monto_reduccion monto_adicional monto_prorroga monto_complementario{
  replace `x' = 0 if missing(`x') 
}

drop monto_reduccion monto_adicional monto_prorroga monto_complementario //por ahora nos deshacemos de los montos de arriba para averiguar despues que hacer con respecto a ellos
duplicates drop //Los montos "adicionales" hacen que hayan muchos duplicados

//IDS:
gisid codigoconvocatoria num_item n_cod_contrato ruc_destinatario_pago  

//cambiamos el nombre para que coincida con otras bases
rename num_item n_item

save "$data_pro\OSCE_contratos", replace

*******************************************************************
**# BASE DE ADJUDICACIONES
*******************************************************************

clear

tempfile OSCE_adjudicaciones
save `OSCE_adjudicaciones', emptyok

// Unificamos los archivos anuales de la base de adjudicaciones

forval i = 2018/2023{
	import excel using "$data_raw\scraped_files\DATOS_DE_ADJUDICACIONES\conosceadjudicaciones`i'.xlsx", cellrange(A2) firstrow case(lower) clear
	if _N != 0 {
		append using `OSCE_adjudicaciones'
		save `OSCE_adjudicaciones', replace
	}
}

preserve
include "$documentation\Descripcion_de_las_bases\Desc_var.do"
quietly export excel varname varlabel using "$documentation\Descripcion_de_las_bases\Descripción_bases.xlsx", sheet("OSCE_adjudicaciones") firstrow(variables) sheetreplace
restore

//IDS: codigoconvocatoria n_item ruc_proveedor
duplicates drop codigoconvocatoria n_item ruc_proveedor, force //6 obs son asumido como errores de registro

save "$data_pro\OSCE_adjudicaciones", replace


*******************************************************************
**# BASE COMPLETA
*******************************************************************

use "$data_pro\OSCE_contratos", clear //ids: codigoconvocatoria n_item n_cod_contrato ruc_destinatario_pago

rename ruc_contratista ruc_proveedor

*** Le agregamos informacion sobre adjudicaciones

merge m:1 codigoconvocatoria n_item ruc_proveedor using "$data_pro\OSCE_adjudicaciones", keep(1 3) gen(merge_contrat_adjud) //ids: codigoconvocatoria n_item ruc_proveedor

*** Le agregamos informacion sobre la convocatorias

merge m:1 codigoconvocatoria n_item using "$data_pro\OSCE_convocatoria", keep(3 4 5) gen(merge_convocatoria) update replace //hay nonmissing conflicts usualmente por una variable de descripcion que le faltan comillas o que esta incompleta, es mejor usar replace pues la base de convocatorias es preferida

//Le damos un orden a la base: Convocatoria > Contrato > Item
sort codigoconvocatoria n_cod_contrato n_item


// Para tener una mejor visibilidad en browse
quietly: ds
local vars `r(varlist)'
foreach v of local vars {
	char `v'[_de_col_width_] 20
}


// Limpiamos las fechas volviendo todas los 1900 en missings
quietly: ds fecha*
local vars `r(varlist)'
foreach v of local vars {
	di "`v'"
	gen temp = year(`v') if `v'!=.
	replace `v' =. if temp==1900
	drop temp
}
	

//Se limpian los urls de contrato
replace urlcontrato = "" if urlcontrato=="SIN URL DE ARCHIVO DE CONTRATO "

drop if urlcontrato == "http://zonasegura.seace.gob.pe/documentos/mon\docs\contratos\2020\10248\363773211082020154828.pdf" & n_cod_contrato == 1291610

gen year_suscripcion = year(fecha_suscripcion_contrato)
gen month_suscripcion =  month(fecha_suscripcion_contrato)
gen quarteryear_suscripcion= qofd(fecha_suscripcion_contrato)
gen monthyear_suscripcion = mofd(fecha_suscripcion_contrato)
keep if year_suscripcion >=2018 & year_suscripcion <=2023 // Errores en las fechas

levelsof quarteryear_suscripcion, local(times)
foreach time of local times {
    label define YQ `time' `"`= strofreal(`time',"%tq")'"', add
}
label values quarteryear_suscripcion YQ 

levelsof monthyear_suscripcion, local(times)
foreach time of local times {
    label define YM `time' `"`= strofreal(`time',"%tm")'"', add
}
label values monthyear_suscripcion YM
	
save "$data_pro\OSCE_completo", replace

//IDS: codigoconvocatoria n_cod_contrato n_item ruc_proveedor ruc_destinatario_pago

	
	
*******************************************************************
**# CODIGOS CUBSO
*******************************************************************

use "$data_pro\OSCE_completo", clear
replace codigoitem = ustrregexra(codigoitem, "^0+", "") //le quitamos los ceros innecesarios al codigo de item
tempfile OSCE_completo
save `OSCE_completo'


*** Codigos de Bienes
import excel using "$documentation\Catálogo Único de Bienes, Servicios y Obras (CUBSO)\Cubso al 02.07.2023.xlsx", sheet("BIENES.") cellrange(B7) clear
drop if B==""
rename C itemcubso
gen objetocontractual = "Bien"
gen codigoitem = substr(B, 9, 17)
replace codigoitem = ustrregexra(codigoitem, "^0+", "") //le quitamos los ceros innecesarios al codigo de item
tempfile codigos_item
save `codigos_item'


*** Codigos de Servicios
import excel using "$documentation\Catálogo Único de Bienes, Servicios y Obras (CUBSO)\Cubso al 02.07.2023.xlsx", sheet("SERVICIOS") cellrange(B7) clear
drop if B==""
rename C itemcubso
gen objetocontractual = "Servicio"
gen codigoitem = substr(B, 9, 17)
replace codigoitem = ustrregexra(codigoitem, "^0+", "") //le quitamos los ceros innecesarios al codigo de item
append using `codigos_item'
save `codigos_item', replace


*** Codigos de Obras
import excel using "$documentation\Catálogo Único de Bienes, Servicios y Obras (CUBSO)\Cubso al 02.07.2023.xlsx", sheet("OBRAS") cellrange(B7) clear
drop if B==""
rename C itemcubso
gen objetocontractual = "Obra"
gen codigoitem = substr(B, 9, 17)
replace codigoitem = ustrregexra(codigoitem, "^0+", "") //le quitamos los ceros innecesarios al codigo de item
append using `codigos_item'
save `codigos_item', replace


*** Codigos de Consultoría de Obras
import excel using "$documentation\Catálogo Único de Bienes, Servicios y Obras (CUBSO)\Cubso al 02.07.2023.xlsx", sheet("CONSULTORIA DE OBRAS") cellrange(B7) clear
drop if B==""
rename C itemcubso
gen objetocontractual = "Consultoría de Obra"
gen codigoitem = substr(B, 9, 17)
replace codigoitem = ustrregexra(codigoitem, "^0+", "") //le quitamos los ceros innecesarios al codigo de item
append using `codigos_item'
save `codigos_item', replace

use `OSCE_completo', clear
merge m:1 codigoitem using `codigos_item', gen(merge_item) keep(1 3 4 5) keepusing(itemcubso objetocontractual) update replace

//con esto ya hemos actualizado y corregido parte de los titulos de producto, ahora tenemos que identificar los demas errores en el registro

destring codigoitem, replace

preserve
keep objetocontractual codigoitem itemcubso merge_item
duplicates drop codigoitem itemcubso, force
drop if codigoitem==.
duplicates report codigoitem
sort codigoitem itemcubso merge_item, stable
bysort codigoitem : gen n_rep = _n
bysort codigoitem : gen N_rep = _N
bysort codigoitem : drop if _n != _N
drop n_rep N_rep
tempfile correccion_items
save `correccion_items'
restore

merge m:1 codigoitem using `correccion_items', keep(1 3 4 5) update replace gen(correccion_item)

labmask codigoitem if codigoitem!=., values(itemcubso)

gen d_pandemia = 0
replace d_pandemia=1 if year_suscripcion>=2020
label define d_pandemia 1 "Pandemia" 0 "Pre-pandemia"
label values d_pandemia d_pandemia
gen contratacion = inlist(tipoprocesoseleccion,"Contratación Directa", "Contratación Directa (Petroperú)")
label define contratacion 1 "Direct Deal" 0 "Otros Procesos de Selección"
label values contratacion contratacion

tab contratacion quarteryear_suscripcion, nofreq col
tab contratacion d_pandemia, nofreq col chi
ranksum contratacion, by(d_pandemia)

save "$data_pro\OSCE_completo", replace

// Tenemos 408,539 observaciones




