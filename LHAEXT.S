
	include	"jaguar.inc"


;bp	equr	a4

LZH_CRC16	.equ	$A001
;LZH_BufSiz	.equ	$4000

LZH_NC	.equ	$200-2
LZH_NP	.equ	14
LZH_NT	.equ	19
LZH_NPT	.equ	$80

LZH_CBIT	.equ	9
LZH_PBIT	.equ	4
LZH_TBIT	.equ	5

LZH_DSIZ	.equ	$2000
LZH_DSIZ2	.equ	LZH_DSIZ*2

	; rsreset
LZH_HeadSiz	.equ		0		; rs.b	1
LZH_HeadChk	.equ		1		; rs.b	1
LZH_HeadId		.equ		2		; rs.b	3
LZH_Method		.equ		5		; rs.b	1
								; rs.b	1 => +1
LZH_Pacsiz		.equ		7		; rs.b	4
LZH_Orgsiz		.equ		11		; rs.b	4
LZH_FTime		.equ		15		; rs.b	2
LZH_FDate		.equ		17		; rs.b	2
LZH_FAttr		.equ		19		; rs.b	2
LZH_FnLen		.equ		21		; rs.b	1
LZH_Fname		.equ		22		; rs.b	$80
LZH_LzHead		.equ		22+$80	; rs.b	0


	;section	text
LZH_main:
	move.l		#INITSTACK, sp	


	lea			DEBUT_BSS,a0
	lea			FIN_RAM,a1
	moveq		#0,d0
	
boucle_clean_BSS:
	move.b		d0,(a0)+
	cmp.l		a0,a1
	bne.s		boucle_clean_BSS



;
; make CRC table
;
LZH_makecrc:
	lea		LZH_crctbl,a0
	moveq	#0,d2
LZH_makecrc_1:
	move	d2,d0
	moveq	#8-1,d1
LZH_makecrc_2:
	lsr		#1,d0
	bcc.s	LZH_makecrc_3
	eor		#LZH_CRC16,d0
LZH_makecrc_3:
	dbra	d1,LZH_makecrc_2
	
	move	d0,(a0)+
	addq.b	#1,d2
	bne.s	LZH_makecrc_1
;
; get Header
;
; +0 = Size of archived file header
; +1 =  Header checksum
	lea		LZH_fichier_compresse+2,a5

;
; test header id
;
	cmp.b	#'-',(a5)+
	bne		LZH_errhdr
	cmp.b	#'l',(a5)+
	bne		LZH_errhdr
	cmp.b	#'h',(a5)+
	bne		LZH_errhdr

	move.b	(a5)+,d0			; version de la compression
	sub.b	#'0',d0
	move.b	d0,d6

	beq.s	LZH_loc15
	subq.b	#4,d0
	beq.s	LZH_loc15
	subq.b	#1,d0
	bne		LZH_errhdr

LZH_loc15:
	cmp.b	#'-',(a5)+
	bne		LZH_errhdr

; 4 bytes  Compressed size (n)	
	moveq	#0,d0
	move.b	3(a5),d0
	lsl.l	#8,d0
	move.b	2(a5),d0
	lsl.l	#8,d0
	move.b	1(a5),d0
	lsl.l	#8,d0
	move.b	(a5),d0
	move.l	d0,LZH_packsize

; 4 bytes  Uncompressed size
	moveq	#0,d0
	move.b	3+4(a5),d0
	lsl.l	#8,d0
	move.b	2+4(a5),d0
	lsl.l	#8,d0
	move.b	1+4(a5),d0
	lsl.l	#8,d0
	move.b	4(a5),d0
	move.l	d0,LZH_origsize
	move.l	d0,LZH_origsize_2

;
; get original CRC
;
	lea		LZH_fichier_compresse+LZH_Fname,a1
	move.l	a1,LZH_fnptr			; pointeur sur le nom original du fichier

	moveq	#0,d0
	move.b	-1(a1),d0				; path length in bytes

	move.l	a1,a0
	add		d0,a0					; position sur CRC16

	moveq	#0,d0
	move.b	1(a0),d0
	lsl.l	#8,d0
	move.b	(a0),d0
	move	d0,LZH_orgcrc			; CRC16
	
	addq.l	#2,a0
	move.l	a0,LZH_inpptr			; compressed data

	;move.b	#' ',(a0)+				; clear le CRC ?
	;clr.b	(a0)
;
; display file name
;
	;bsr	disp		;output file name
	;clr.b	-(a0)
;
; check existence of file
;

	;bra		LZH_MN1		;pour d‚buggage

;
; create a new file
;
;LZH_mn1:
;
; decode
;
	clr		LZH_curcrc
	;move.l	#-1,LZH_inpptr

; quand pas compresse
	;tst		d6
	;beq.s	LZH_copy20
	
	;move.l	#LZH_fichier_compresse+LZH_LzHead,LZH_inpptr
	
	bsr		LZH_decode
LZH_loc20:

; set time-stamp

	;lea		LZH_cpyhdr,a0
	;movep	LZH_Fdate+1(a0),d0
	;move.b	LZH_fdate(a0),d0
	;move	d0,LZH_filetime+2

	;movep	LZH_Ftime+1(a0),d0
	;move.b	LZH_Ftime(a0),d0
	;move	d0,LZH_filetime

; calcul CRC

LZH_calccrc:
	lea		LZH_text,a0
	move.l	LZH_origsize_2,d0
	move	LZH_curcrc,d1	;bx
	lea		LZH_crctbl,a1

LZH_calccrc_do:
	clr.w	d2
	move.b	(a0)+,d2
	eor.b	d1,d2

	lsr		#8,d1
	add		d2,d2
	move	(a1,d2.w),d2

	eor		d2,d1

	subq.l	#1,d0
	bne.s	LZH_calccrc_do

	move	d1,LZH_curcrc



;
; check CRC
;
	move	LZH_curcrc,d0
	cmp		LZH_orgcrc,d0
	bne		LZH_errcrc

	;bra		LZH_mainloop
LZH_exit:
LZH_exit1:
	moveq	#0,d0

EDZ_FIN:
	bra		EDZ_FIN
	
LZH_exit2:
	ILLEGAL


LZH_errhdr:
	;lea		LZH_header,a1
	bra		LZH_errout
LZH_brokenerr:
	;lea		LZH_broken,a1
	bra		LZH_errout
LZH_errcrc:
	;bsr		LZH_unlink
	;lea		LZH_crcmess,a1
	bra		LZH_errout1
LZH_errwrite:

	;bsr		LZH_unlink
	;lea		LZH_write,a1
LZH_errout:
	;bsr	disp
	;lea		LZH_error,a1
LZH_errout1:
	;bsr	disp
	moveq	#1,d0
	bra		LZH_exit2


;
; extract routines
;
LZH_decode:

	moveq	#0,d0
	move	d0,LZH_blocksize
	move	d0,LZH_bitbuf
	move	d0,LZH_subbitbuf
	move	d0,LZH_bitcount

	moveq	#16,d0
	bsr		LZH_fillbuf

	lea		LZH_text,a6			;di
	bra		LZH_entry
LZH_loop:
	bsr		LZH_decode_c_st1
	cmp		#$100,d0
	bhs.s	LZH_loc50

	move.b	d0,(a6)+
	;cmp.l	#LZH_text+LZH_DSIZ2,a6
	;blo.s	LZH_entry
	;bsr		LZH_putbuf
LZH_entry:

	TST.L	LZH_inpptr
	BEQ		LZH_bug

	subq.l	#1,LZH_origsize
	bhs.s	LZH_loop
	bra.s	LZH_loc53
LZH_loc50:
	move	d0,d2		;cx
	sub		#$100-3,d2
	bsr		LZH_decode_p_st1

	move	d2,-(sp)	;cx

	move.l	a6,a5		;si
	subq.l	#1,a5		;si
	sub		d0,a5

LZH_circ0:	
	cmp.l	#LZH_text,a5
	bhs.s	LZH_circ1
	lea		LZH_DSIZ2(a5),a5
	bra.s	LZH_circ0
LZH_circ1:

LZH_do1:
	move.b	(a5)+,(a6)+

	;cmp.l	#LZH_text+LZH_DSIZ2,a5
	;blo.s	LZH_circ2
	;lea		-LZH_DSIZ2(a5),a5
LZH_circ2:
	;cmp.l	#LZH_text+LZH_DSIZ2,a6
	;blo.s	LZH_loc52

	;move	d2,-(sp)
	;pea		(a5)		;si
	;bsr		LZH_putbuf
	;move.l	(sp)+,a5
	;move	(sp)+,d2
LZH_loc52:
	TST		D2
	BEQ		LZH_bug

	;subq.l	#1,LZH_origsize
	;beq.s	LZH_loc53

	subq	#1,d2
	bne.s	LZH_do1

	TST.L	LZH_inpptr
	BEQ		LZH_bug


	moveq	#0,d2
	move	(sp)+,d2
	sub.l	d2,LZH_origsize
	bhs		LZH_loop
LZH_loc53:
	rts
	;bra		LZH_putbuf
;
;
;
LZH_read_pt_len:
	move	d4,-(sp)	;si
	move	d3,d0		;al=dl
	bsr		LZH_getbits
	cmp		d4,d0		;comp ax et si
	bhi		LZH_brokenerr

	lea		LZH_pt_len,a6	;di

	tst		d0
	bne.s	LZH_loc1

	move	(sp)+,d2
	BEQ		LZH_bug
LZH_loc2:
	move.b	d0,(a6)+
	subq	#1,d2
	bne.s	LZH_loc2

	cmp.l	#LZH_fin_pt_len,a6
	bhi		LZH_bug

	move	d3,d0
	bsr		LZH_getbits
	move	#256,d2
	lea		LZH_pt_table,a6
LZH_loc3:
	move	d0,(a6)+
	subq	#1,d2
	bne.s	LZH_loc3
	rts
	
LZH_loc1:
	move.l	a6,a3
	add		d2,a3		;+di

	move.l	a6,a5		;si
	add		d0,a5		;ax=n
LZH_do1d1:
	moveq	#3,d0
	bsr		LZH_getbits
	cmp		#7,d0
	bne.s	LZH_not1

	move	LZH_bitbuf,d1
LZH_while1:
	add		d1,d1
	bcc.s	LZH_endw
	addq	#1,d0
	bra.s	LZH_while1
LZH_endw:
	move	d0,-(sp)
	subq	#6,d0
	bsr		LZH_fillbuf
	move	(sp)+,d0
LZH_not1:
	move.b	d0,(a6)+	;stosb
	cmp.l	a3,a6
	bne.s	LZH_not2

	moveq	#2,d0
	bsr		LZH_getbits
	move	d0,d2
	moveq	#0,d0
	tst		d2
;	beq.s	LZH_not2
	BEQ		LZH_bug
LZH_loc11:
	move.b	d0,(a6)+
	subq	#1,d2
	bne.s	LZH_loc11

LZH_not2:
	cmp.l	a5,a6
	blo.s	LZH_do1d1


	cmp.l	#LZH_fin_pt_len,a6
	bhi		LZH_bug


	move	(sp)+,d4	;si

	lea		LZH_pt_len,a4

	move.l	a4,d2		;cx=bp
	sub.l	a6,d2		;-di
	add		d4,d2		;+si
	beq.s	LZH_none1
	moveq	#0,d0
LZH_loc12:
	move.b	d0,(a6)+
	subq	#1,d2
	bne.s	LZH_loc12
LZH_none1:

	move	d4,d0		;ax=si
	moveq	#8,d2		;cx
	lea		LZH_pt_table,a6	;di
	bra		LZH_make_table
;
;
LZH_read_c_len:
	moveq	#LZH_CBIT,d0
	bsr		LZH_getbits

	cmp		#LZH_NC,d0
	bhi		LZH_brokenerr

	lea		LZH_c_len,a6	;di

	tst		d0
	bne.s	LZH_not11

	move	#LZH_NC,d2
LZH_lop1:
	move.b	d0,(a6)+
	subq	#1,d2
	bne.s	LZH_lop1

	CMP.L	#LZH_FIN_C_LEN,A6
	BHI		LZH_bug

	moveq	#LZH_CBIT,d0
	bsr		LZH_getbits
	move	#4096,d2
	lea		LZH_c_table,a6
LZH_lop2:
	move	d0,(a6)+
	subq	#1,d2
	bne.s	LZH_lop2
	rts
	
LZH_not11:
	move.l	a6,a3		;dx
	add.l	d0,a3		;ax=n
	pea	(a6)		;di

LZH_do100:
	move	LZH_bitbuf,d0
	move	d0,d1
	lsr		#8,d1
	add		d1,d1
	lea		LZH_pt_table,a0
	move	(a0,d1.w),d1

	lea		LZH_read_c_len_1,a5		;si
	moveq	#LZH_NT,d2
	bra		LZH_tree1

LZH_read_c_len_1:
	move	d1,-(sp)	;bx
	lea		LZH_pt_len,a0
	CLR		D0
	move.b	(a0,d1.w),d0
	bsr		LZH_fillbuf
	move	(sp)+,d0

	sub		#2,d0
	bhi.s	LZH_loc68

	bne.s	LZH_loc65

	moveq	#LZH_CBIT,d0
	bsr		LZH_getbits
	add		#20,d0
	move	d0,d2

	bra.s	LZH_loc67
LZH_loc65:
	addq	#1,d0
	bne.s	LZH_loc66

	moveq	#4,d0
	bsr		LZH_getbits
	add		#3,d0
	move	d0,d2

	bra.s	LZH_loc67
LZH_loc66:
	moveq	#1,d2
LZH_loc67:
	moveq	#0,d0
LZH_lopxx1:
	TST		D2
	BEQ		LZH_bug
	move.b	d0,(a6)+
	subq	#1,d2
	bne.s	LZH_lopxx1
	bra.s	LZH_loc69
LZH_loc68:
	move.b	d0,(a6)+
LZH_loc69:
	cmp.l	a3,a6
	blo.s	LZH_do100


	CMP.L	#LZH_FIN_C_LEN,A6
	BHI		LZH_bug

	moveq	#0,d0
	move.l	#LZH_c_len+LZH_NC,d2
	sub.l	a6,d2
	BEQ.S	LZH_NONE2
LZH_fil0:
	move.b	d0,(a6)+
	subq	#1,d2
	bne.s	LZH_fil0
LZH_NONE2:
	move	#LZH_NC,d0
	move.l	(sp)+,a4

	moveq	#12,d2		;cx
	lea		LZH_c_table,a6
	bra		LZH_make_table

LZH_decode_c:

LZH_decode_c_st1_2:
	pea		(a6)
	moveq	#16,d0
	bsr		LZH_getbits
	subq	#1,d0
	move	d0,LZH_blocksize

	move	#LZH_NT,d4		;si
	moveq	#LZH_TBIT,d3	;dx
	moveq	#3,d2		;cx
	bsr		LZH_read_pt_len

	bsr		LZH_read_c_len

	move	#LZH_NP,d4		;si
	moveq	#LZH_PBIT,d3	;dx
	moveq	#-1,d2		;cx

	bsr		LZH_read_pt_len

	move.l	(sp)+,a6
	bra		LZH_decode_c_st1_3

LZH_decode_c_st1:
	subq	#1,LZH_blocksize
	blo		LZH_decode_c_st1_2
LZH_decode_c_st1_3:
	move	LZH_bitbuf,d1		;bx

	lsr		#4,d1
	moveq	#4,d2			;cx
	add		d1,d1
	lea		LZH_c_table,a0
	move	(a0,d1.w),d1

	cmp		#LZH_NC,d1
	bhs.s	LZH_loc1111
LZH_decode_c_st1_1:
	move	d1,-(sp)
	lea		LZH_c_len,a0
	clr		d0
	move.b	(a0,d1.w),d0
	bsr		LZH_fillbuf
	move	(sp)+,d0
	rts
	
LZH_loc1111:
	move	LZH_bitbuf,d0
	asl.b	d2,d0
	lea		LZH_decode_c_st1_1,a5	;si
	move	#LZH_NC,d2			;cx
LZH_tree0:
	lea		LZH_left,a0
	add.b	d0,d0
	bcc.s	LZH_loc1d1
	lea		LZH_right,a0
LZH_loc1d1:
	move	(a0,d1.w),d1
LZH_tree1:
	cmp		d2,d1
	bhs.s	LZH_tree0
	jmp		(a5)		;si
;
;
;
LZH_decode_p_st1:
	move	d2,-(sp)
	moveq	#0,d1
	move.b	LZH_bitbuf,d1	;poids fort dans bl
	add		d1,d1
	lea		LZH_pt_table,a0
	move	(a0,d1.w),d1

	cmp		#LZH_NP,d1
	bhs		LZH_loc2d2
LZH_decode_p_st1_1:
	move	d1,-(sp)
	lea		LZH_pt_len,a0
	clr		d0
	move.b	(a0,d1.w),d0
	bsr		LZH_fillbuf
	move	(sp)+,d0
	cmp		#1,d0
	bls.s	LZH_loc3d3
	subq	#1,d0
	move	d0,d2
	bsr		LZH_getbits
	moveq	#1,d1
	asl		d2,d1

	or		d1,d0
LZH_loc3d3:
	move	(sp)+,d2
	rts
	
LZH_loc2d2:
	move.b	LZH_bitbuf+1,d0		;poids faible
	lea		LZH_decode_p_st1_1,a5	;si
	moveq	#LZH_NP,d2
	bra		LZH_tree0
;
;
;
LZH_make_table:
	move	d0,LZH_nchar
	add		d0,d0
	move	d0,LZH_avail_mt
	move	d2,LZH_tablebits
	move.l	a6,LZH_table

	moveq	#16,d0
	sub		d2,d0
	move.b	d0,LZH_restbits

	moveq	#1,d0
	asl		d2,d0
	move	d0,d2
	BEQ		LZH_bug
	moveq	#0,d0
LZH_make_table_stos:
	move	d0,(a6)+
	subq	#1,d2
	bne.s	LZH_make_table_stos

	moveq	#0,d4		;si
	move	#$8000,d1	;bx
	moveq	#1,d3		;dx
	
LZH_make_table_do200:
	move.l	a4,a6		;di=bp
	move	LZH_nchar,d2
	BEQ		LZH_bug
LZH_make_table_do2:
	move	d3,d0		;al=dl
LZH_make_table_scasb:
	cmp.b	(a6)+,d0
	beq.s	LZH_make_table_fnd
	subq	#1,d2
	bne.s	LZH_make_table_scasb
	bra		LZH_mt1
LZH_make_table_fnd:
	bne		LZH_mt1
	move.l	a6,d0
	sub.l	a4,d0
	subq	#1,d0
	move	d2,-(sp)	;cx

	pea		(a6)		;di
;
; bx=weight
; si=code
; dx=len
;
	moveq	#0,d2
	move.b	LZH_restbits,d2
	move	d4,d7
	lsr		d2,d7
	add		d7,d7
	move.l	LZH_table,a6
	add		d7,a6

	move	d1,-(sp)		;bx

	cmp		LZH_tablebits,d3		;dx
	bhi.s	LZH_make_table_loc1
	lsr		d2,d1
	move	d1,d2
	BEQ		LZH_bug
LZH_make_table_stosw1:
	move	d0,(a6)+
	subq	#1,d2
	bne.s	LZH_make_table_stosw1
	bra.s	LZH_make_table_loc2
LZH_make_table_loc1:
;
; di=taddr
; si=
; cx=
; ax=char
;
	move	d4,-(sp)
	move	LZH_tablebits,d2
	asl		d2,d4

	neg		d2
	add		d3,d2
	BEQ		LZH_bug
LZH_make_table_do3:
	tst		(a6)
	bne.s	LZH_make_table_loo
	move	LZH_avail_mt,d1	;bx
	lea		LZH_right,a0
	clr		(a0,d1.w)
	lea		LZH_left,a0
	clr		(a0,d1.w)

	move	d1,(a6)
	addq	#2,LZH_avail_mt
LZH_make_table_loo:
;	move.l	d1,a0
;	moveq	#0,d1
;	move	(a0),d1
	MOVE	(A6),A6

;	add	d1,d1
	ADD		D4,D4
	bcc.s	LZH_make_table_noc1
	add.l	#LZH_right,A6
	bra.s	LZH_make_table_noc2
LZH_make_table_noc1:
	add.l	#LZH_left,A6
LZH_make_table_noc2:
	subq	#1,d2
	bne.s	LZH_make_table_do3
	move	d0,(a6)

	move	(sp)+,d4
LZH_make_table_loc2:
	move	(sp)+,d1
	move.l	(sp)+,a6
	move	(sp)+,d2
	add		d1,d4
	bcs		LZH_mt2

	TST		D2
	BEQ		LZH_bug

	SUBQ	#1,d2		;DEBUGGAGE
	bne		LZH_make_table_do2
LZH_mt1:
	addq	#1,d3
	lsr		#1,d1
	bcc		LZH_make_table_do200
LZH_mt2:
	rts
;
; retourne d0 bits
;
LZH_bug:	
	illegal

LZH_getbits:
	cmp		#16,d0
	bhi		LZH_bug

	move	d2,-(sp)
	moveq	#16,d2
	sub		d0,d2

	move	LZH_bitbuf,-(sp)
	bsr		LZH_fillbuf
	move	(sp)+,d0
	lsr		d2,d0
	move	(sp)+,d2
	rts
;
; shift bitbuf n bits left, read n bits
;
; rafraichit bitbuf_ avec d0 bits
;
LZH_fillbuf:
	cmp		#16,d0
	bhi		LZH_bug


	movem.l	d1/d2/d3,-(sp)

	move	d0,d2
	move	LZH_bitcount,d1
	move	LZH_bitbuf,d3

	move	LZH_subbitbuf,d0

	cmp		d1,d2
	bls.s	LZH_loc100

	sub		d1,d2
	asl		d1,d3
	rol.b	d1,d0
	add.b	d0,d3

	moveq	#8,d1
LZH_fb1:
	bsr		LZH_getc
	cmp		d1,d2
	bls		LZH_loc100
	sub		d1,d2
	asl		#8,d3
	move.b	d0,d3
	bra		LZH_fb1

LZH_loc100:
	sub		d2,d1
	move	d1,LZH_bitcount

	asl		d2,d3
	asl		d2,d0

	move	d0,d7
	lsr		#8,d7
	add.b	d7,d3

	move	d3,LZH_bitbuf
	and		#$ff,d0
	move	d0,LZH_subbitbuf

	movem.l	(sp)+,d1/d2/d3
	rts
;
; getc :
;
; retourne d0=1 octet lu
;
LZH_getc:
	move.l	LZH_inpptr,a0
	;cmp.l	#LZH_inpbuf_FIN,a0
	;blo.s	LZH_getc_ok

	
	
LZH_getc_ok:
	move.b	(a0)+,d0
	move.l	a0,LZH_inpptr
	rts

	
;
; liste des variables utilis‚es
;
	.data
;
; bytes...
;LZH_cright:	dc.b	"LHA's SFX 2.11",13,10,0
;LZH_myself:
;	dc.b	"SEKA.LZH",0
;	DC.B	"PAK.LZH",0
	even

	.long
LZH_fichier_compresse:
LZH_inpbuf:
	.incbin	"c:/jaguar/YM_old/Syntax Terror - TEx.ym"				; YM6
LZH_inpbuf_FIN:
	even
	
	.phrase
	
	.bss

DEBUT_BSS:

LZH_left:			ds.w	2*LZH_NC-1
LZH_right:			ds.w	2*LZH_NC-1
LZH_c_table:		ds.w	4096
LZH_pt_table:		ds.w	256
LZH_c_len:			ds.b	LZH_NC
LZH_FIN_C_LEN:
LZH_pt_len:		ds.b	LZH_NPT
LZH_fin_pt_len:

LZH_avail_mt:		ds.w	1
LZH_nchar:			ds.w	1
LZH_tablebits:	ds.w	1
LZH_table:			ds.l	1
LZH_restbits:		ds.b	1
	even

; words,longs...
LZH_packsize:		ds.l	1
LZH_origsize:		ds.l	1
LZH_origsize_2:	ds.l	1
LZH_fnptr:			ds.l	1
LZH_inpptr:			ds.l	1
;LZH_filetime:		ds.l	1

LZH_orgcrc:			ds.w	1
LZH_infile:			ds.w	1
LZH_outfile:			ds.w	1
LZH_curcrc:			ds.w	1

LZH_bitbuf:			ds.w	1
LZH_subbitbuf:		ds.w	1
LZH_bitcount:			ds.w	1

LZH_blocksize:		ds.w	1

LZH_crctbl:	ds.w	$100
LZH_cpyhdr:	ds.b	LZH_LzHead
	even
LZH_text:		ds.b	LZH_DSIZ2

FIN_RAM: