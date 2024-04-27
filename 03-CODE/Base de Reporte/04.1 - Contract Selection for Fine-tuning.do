//------------------------------------------------------------------------------
//		   00 Compras públicas Peru. Importación y limpieza
//------------------------------------------------------------------------------

//Author: Matias Villalba
//Start Date: 09/04/2023
//Input: Bases de los datos abiertos del OSCE

***********************************************************
*	0.          Set up                             
***********************************************************

*1. Directories _________________________________________________________
version 17

* Directories
	global root 			"C:\Users\matia\OneDrive - Universidad del Pacífico\01-Medidas_emergencia_PE"
	global data_raw			"$root\01-DATA_PERU\01-DATA_RAW"
	global data_pro 		"$root\01-DATA_PERU\02-DATA_PROCESSED\"
	global documentation	"$root\01-DATA_PERU\04-DATA_DOCUMENTATION\"
	
********************************************************************************

	
********************************************************************************
	
	use "$data_pro\OSCE_to_sample", clear
	
	//hacemos un sample por año
	set seed 42
	sample 100, count by(year_suscripcion)
	sort urlcontrato
	
	
	qui ds
	foreach var of varlist `r(varlist)' {
		qui count if missing(`var') // count the number of missing values for each variable
		if `r(N)' == _N { // if the count equals the total number of observations
			display "Dropping variable `var' as all observations are missing"
			drop `var'
		}
	}
	
	save "$data_pro\OSCE_finetune_sample", replace
	
	
	
	

