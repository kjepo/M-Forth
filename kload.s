.macro  KLOAD register, addr            // MacOS way of doing ADR
	ADRP \register, \addr@PAGE     
	ADD \register, \register, \addr@PAGEOFF
.endm
