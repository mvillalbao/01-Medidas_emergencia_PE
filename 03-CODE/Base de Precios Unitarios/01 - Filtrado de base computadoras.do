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
	global data_pro 		"$root\01-DATA_PERU\02-DATA_PROCESSED\"
	global documentation	"$root\01-DATA_PERU\04-DATA_DOCUMENTATION\"
	
************************************************************

use "$data_pro\OSCE_completo", clear

keep if objetocontractual == "Bien"

preserve
import excel using "$documentation\Computer_codes.xlsx", firstrow case(lower) clear
destring codigoitem, replace
tempfile codigos_computadora
save `codigos_computadora'
restore

merge m:1 codigoitem using `codigos_computadora', gen(merge_computadora) keep(1 3)
keep if merge_computadora==3
//solo tenemos 221 observaciones


/*

tab objetocontractual
tab sector
tab sistema_contratacion
tab tipoprocesoseleccion

encode tipoprocesoseleccion, gen(temp)

labelbook temp

gen tipodeproceso_final = tipodeprocesoseleccion
replace tipodeproceso_final = "Contratación Directa" if inlist(tipodeprocesoseleccion, "Contratación Directa", "Contratación Directa (Petroperú)", "")
*/

save "$data_pro\OSCE_computadoras_filtrado", replace
