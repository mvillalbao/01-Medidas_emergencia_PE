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
	global root 			"D:\01-Medidas_emergencia_PE_2024"
	global data_raw			"$root\01-DATA_RAW"
	global data_pro 		"$root\02-DATA_PROCESSED\"
	global documentation	"$root\04-DATA_DOCUMENTATION\"
	
************************************************************

use "$data_pro\OSCE_completo", clear

keep if sector == "SALUD"
keep if objetocontractual == "Bien" | objetocontractual == "Servicio"
keep if year_suscripcion>=2018 & year_suscripcion<=2022

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

save "$data_pro\OSCE_completo_filtrado", replace

use "$data_pro\OSCE_completo_filtrado", clear
	
gisid codigoconvocatoria n_cod_contrato n_item ruc_proveedor ruc_destinatario_pago
	
keep codigoconvocatoria n_cod_contrato n_item ruc_proveedor ruc_destinatario_pago urlcontrato
sort codigoconvocatoria n_cod_contrato n_item, stable
bys codigoconvocatoria n_cod_contrato : gen j = _n
	
reshape wide n_item ruc_proveedor ruc_destinatario_pago, i(codigoconvocatoria n_cod_contrato urlcontrato) j(j)
	
drop if urlcontrato == ""
	
//ahora tenemos una observacion por cada contrato
duplicates report urlcontrato
	
tempfile contratos_unicos
save `contratos_unicos'
	
	
//le vamos a agregar la fecha de suscripcion a cada contrato para poder hacer un sample por año
use "$data_pro\OSCE_completo_filtrado", clear
drop if urlcontrato == ""
keep urlcontrato fecha_suscripcion_contrato year_suscripcion
duplicates drop urlcontrato, force
	
tempfile contratos_fecha
save `contratos_fecha'

use `contratos_unicos', clear
merge 1:1 urlcontrato using `contratos_fecha', nogen
	
order codigoconvocatoria n_cod_contrato urlcontrato fecha_suscripcion_contrato year_suscripcion
	
save "$data_pro\OSCE_to_sample", replace

