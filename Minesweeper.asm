.386
.model flat, stdcall
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;includem biblioteci, si declaram ce functii vrem sa importam
includelib msvcrt.lib
extern exit: proc
extern malloc: proc
extern memset: proc				;; !! pt a dezactiva event_clickul in caz de ati apasat pe bomba, decomentati linia 281 si 282 !!
extern printf: proc				;; e lasat asa pt a exemplifica tot ansamblul
extern  srand: proc
extern   rand: proc
extern   time: proc



includelib canvas.lib
extern BeginDrawing: proc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;declaram simbolul start ca public - de acolo incepe executia
public start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;sectiunile programului, date, respectiv cod
.data
;aici declaram date
window_title DB "Proiect Assembly - Minesweeper",0
getint db "%d",13,10,0

area_width EQU 625
area_height EQU 600
area DD 0
x DD 0
y DD 0
i DD 0
j DD 0
coord_matr dd 0
coord_liniara dd 0
nr_bombe_in_jur dd 0
ik DD 0
jk DD 0
x0 DD 100
y0 DD 100
gmover dd 0
format Db "(%d,%d)",13,10,0
format2 Db "(%d)",13,10,0

matrix dd   1,1,1,0,0,1,0,0,1,1
	   dd   0,0,1,0,1,0,1,1,0,1
	   dd   0,0,1,0,0,0,0,1,0,1
	   dd   0,0,0,1,0,0,1,0,0,0
	   dd   1,0,0,1,1,1,0,0,0,0
	   dd   0,1,0,1,0,1,0,1,0,1
	   dd   0,0,0,1,1,0,0,0,1,0
	   dd   1,0,1,0,0,1,0,1,0,1
	   dd   1,1,0,0,0,0,1,0,1,0
	   dd   0,1,0,0,1,0,0,0,0,0
	  
	   
counter DD 0 ; numara evenimentele de tip timer

arg1 EQU 8
arg2 EQU 12
arg3 EQU 16
arg4 EQU 20

symbol_width EQU 10
symbol_height EQU 20
include digits.inc
include letters.inc

.code
; procedura make_text afiseaza o litera sau o cifra la coordonatele date
; arg1 - simbolul de afisat (litera sau cifra)
; arg2 - pointer la vectorul de pixeli
; arg3 - pos_x
; arg4 - pos_y
make_text proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1] ; citim simbolul de afisat
	cmp eax, 'A'
	jl make_digit
	cmp eax, 'Z'
	jg make_digit
	sub eax, 'A'
	lea esi, letters
	jmp draw_text
make_digit:
	cmp eax, '0'
	jl make_space
	cmp eax, '9'
	jg make_space
	sub eax, '0'
	lea esi, digits
	jmp draw_text
make_space:	
	mov eax, 26 ; de la 0 pana la 25 sunt litere, 26 e space
	lea esi, letters
	
draw_text:
	mov ebx, symbol_width
	mul ebx
	mov ebx, symbol_height
	mul ebx
	add esi, eax
	mov ecx, symbol_height
bucla_simbol_linii:
	mov edi, [ebp+arg2] ; pointer la matricea de pixeli
	mov eax, [ebp+arg4] ; pointer la coord y
	add eax, symbol_height
	sub eax, ecx
	mov ebx, area_width
	mul ebx
	add eax, [ebp+arg3] ; pointer la coord x
	shl eax, 2 ; inmultim cu 4, avem un DWORD per pixel
	add edi, eax
	push ecx
	mov ecx, symbol_width
bucla_simbol_coloane:
	cmp byte ptr [esi], 0
	je simbol_pixel_alb
	mov dword ptr [edi], 0
	jmp simbol_pixel_next
simbol_pixel_alb:
	mov dword ptr [edi], 0FFFFFFh
simbol_pixel_next:
	inc esi
	add edi, 4
	loop bucla_simbol_coloane
	pop ecx
	loop bucla_simbol_linii
	popa
	mov esp, ebp
	pop ebp
	ret
make_text endp

; un macro ca sa apelam mai usor desenarea simbolului
make_text_macro macro symbol, drawArea, x, y
	push y
	push x
	push drawArea
	push symbol
	call make_text
	add esp, 16
endm
;arg1-x
;arg2-y
;arg3-lungime
;arg4-culoare
linie_oriz proc
push ebp
mov ebp, esp
pusha

mov eax,[ebp+arg2]
mov ecx,area_width
mul ecx
add eax,[ebp+arg1]
shl eax,2

add eax,[area]
mov ecx,[ebp+arg3]
mov ebx,[ebp+arg4]
piftie:

mov dword ptr [eax],ebx
add eax,4
loop piftie

popa
mov esp, ebp
pop ebp
ret
linie_oriz endp

linie_oriz_macro macro x,y,lg,cul
push cul
push lg
push y
push x
call linie_oriz
add esp,16
endm


;arg1-x
;arg2-y
;arg3-lungime
;arg4-culoare
linie_vert proc
push ebp
mov ebp, esp
pusha

mov eax,[ebp+arg2]
mov ecx,area_width
mul ecx
add eax,[ebp+arg1]
shl eax,2

add eax,[area]
mov ecx,[ebp+arg3]
mov ebx,[ebp+arg4]
shaorma :

mov dword ptr [eax],ebx
add eax,area_width*4
loop shaorma

popa
mov esp, ebp
pop ebp
ret
linie_vert endp

linie_vert_macro macro x,y,lg,cul
push cul
push lg
push y
push x
call linie_vert
add esp,16
endm


patrat_fill_macro macro x,y,lg,cul
mov ecx,lg
sarma:
	linie_oriz_macro x,y,lg,cul
	inc y
loop sarma ; dec ecx
endm

aduna_val_macro macro i,j ; nr_bombe_in_jur = nr_bombe_in_jur + matrix[i][j]

pusha
mov eax,i
mov ebx,10
mul ebx
add eax,j
shl eax,2

mov ebx,matrix[eax]
add nr_bombe_in_jur,ebx
popa
endm

; functia de desenare - se apeleaza la fiecare click7
; sau la fiecare interval de 200ms in care nu s-a dat click
; arg1 - evt (0 - initializare, 1 - click, 2 - s-a scurs intervalul fara click)
; arg2 - x
; arg3 - y
draw proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1]
	cmp eax, 1
	jz evt_click
	cmp eax, 2
	jz evt_timer ; nu s-a efectuat click pe nimic
	;mai jos e codul care intializeaza fereastra cu pixeli albi
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	push 255
	push area
	call memset
	add esp, 12
	jmp afisare_litere
	
evt_click:
		;cmp gmover,1
		;je final
		
		mov nr_bombe_in_jur,0
		mov eax, area_width
		mov ebx, [ebp+arg3];y
		mul ebx
		add eax, [ebp+arg2];x
		shl eax, 2
		add eax,[area]
		mov dword ptr[eax], 0FF0000h
		;jmp afisare_litere
		
		mov eax,[ebp+arg2];x
		mov ebx,[ebp+arg3];y
		mov x,eax
		mov y,ebx
		

	cmp y,100                   ;;
	jl final					;;
		cmp y,500				;;
		jg final 				;;
			cmp x,100			;; verifica daca suntem in patrat
			jl final			;;
				cmp x,500		;;
				jg final		;;
	mov edx,0 
	mov eax,x
	sub eax,x0
	mov ecx,40
	div ecx
	mov j,eax
	mov edx,0   ;; !!!

	mov eax,y
	sub eax,y0
	mov ecx,40
	div ecx     ;; !
	mov i,eax

	mov eax,i
	mov ecx,40
	mul ecx
	add eax,100
	mov y,eax


	mov eax,j
	mov ecx,40
	mul ecx
	add eax,100
	mov x,eax

	mov eax,i
	mov ecx,10
	mul ecx 
	add eax,j
	shl eax,2
	mov ebx,matrix[eax]
	cmp ebx,1

	mov ebx,i
	mov ik,ebx
	mov ebx,j
	mov jk,ebx

	jl nu_e_bomba
	;daca e bomba

		patrat_fill_macro x,y, 40, 000000h
		mov gmover, 1
		jmp final
		
	nu_e_bomba:

	cmp i,0
	jg i_mai_mare_ca_0
		;daca i=0
		inc i
		aduna_val_macro i,j
		dec i
		cmp j,0
		jg i_egal_0_si_j_mai_mare_0
			;daca j=0 si i=0
			inc j
			aduna_val_macro i,j
			inc i
			aduna_val_macro i,j
			jmp fin
		i_egal_0_si_j_mai_mare_0:
		cmp j,9
		
		jl i_egal_0_si_j_mai_mic_9
			;daca j=9 si i=0
			dec j
			aduna_val_macro i,j
			inc i
			aduna_val_macro i,j
			jmp fin
		i_egal_0_si_j_mai_mic_9:
			
			;i=0, 0<j<9
			dec j
			aduna_val_macro i,j
			inc j
			inc j
			aduna_val_macro i,j
			inc i
			aduna_val_macro i,j
			dec j
			dec j
			aduna_val_macro i,j
			jmp fin
	i_mai_mare_ca_0:
	cmp i,9

	jl i_mai_mic_9
		;i=9
		dec i
		aduna_val_macro i,j
		inc i
		
		cmp j,0
		jg i_egal_9_si_j_mai_mare_0
			;daca i=9,j=0
			dec i
			inc j
			aduna_val_macro i,j
			inc i
			aduna_val_macro i,j
			jmp fin
			i_egal_9_si_j_mai_mare_0:

		cmp j,9
		jl i_egal_9_si_j_mai_mic_9
			;daca j=9,i=9
			dec j
			aduna_val_macro i,j
			dec i
			aduna_val_macro i,j
			jmp fin
			i_egal_9_si_j_mai_mic_9:

		;daca i=9,0<j<9

		
		inc j
		aduna_val_macro i,j
		dec j
		dec j
		aduna_val_macro i,j
		dec i
		aduna_val_macro i,j
		inc j
		inc j
		aduna_val_macro i,j
		jmp fin
	i_mai_mic_9:

	;0<i<9
	dec i
	aduna_val_macro i,j
	inc i
	inc i
	aduna_val_macro i,j
	dec i
		cmp j,0
		jg i_intre_1_si_8_j_9
		;0<i<9,j=0
		dec i
		inc j
		aduna_val_macro i,j
		inc i
		aduna_val_macro i,j
		inc i
		aduna_val_macro i,j
		jmp fin
		i_intre_1_si_8_j_9:
		;0<i<9,j>0
	cmp j,9
	jl i_intre_1_si_8_j_intre_1_si_8
		;0<i<9,j=9
		dec i
		dec j
		aduna_val_macro i,j
		inc i
		aduna_val_macro i,j
		inc i
		aduna_val_macro i,j
		jmp fin
	i_intre_1_si_8_j_intre_1_si_8:
		
		dec j
		aduna_val_macro i,j
		dec i
		aduna_val_macro i,j
		inc j
		inc j
		aduna_val_macro i,j
		inc i
		aduna_val_macro i,j
		inc i
		aduna_val_macro i,j
		dec j
		dec j
		aduna_val_macro i,j
fin:
		;scriem numerele in casute
		add x,15
		add y,10
		cmp nr_bombe_in_jur,0
		je bombe_0
		jmp not_bombe_0
		bombe_0:
		make_text_macro '0', area, x, y
		jmp final
		
		not_bombe_0:
		cmp nr_bombe_in_jur,1
		je bombe_1
		jmp not_bombe_1
		bombe_1:
		make_text_macro '1', area, x, y
		jmp final
		
		not_bombe_1:
		cmp nr_bombe_in_jur,2
		je bombe_2
		jmp not_bombe_2
		bombe_2:
		make_text_macro '2', area, x, y
		jmp final
		
		not_bombe_2:
		cmp nr_bombe_in_jur,3
		je bombe_3
		jmp not_bombe_3
		bombe_3:
		make_text_macro '3', area, x, y
		jmp final

		not_bombe_3:
		cmp nr_bombe_in_jur,4
		je bombe_4
		jmp not_bombe_4
		bombe_4:
		make_text_macro '4', area, x, y
		jmp final
		
		not_bombe_4:
		cmp nr_bombe_in_jur,5
		je bombe_5
		jmp not_bombe_5
		bombe_5:
		make_text_macro '5', area, x, y
		jmp final
		
		not_bombe_5:
		cmp nr_bombe_in_jur,6
		je bombe_6
		jmp not_bombe_6
		bombe_6:
		make_text_macro '6', area, x, y
		jmp final
		
		not_bombe_6:
		cmp nr_bombe_in_jur,7
		je bombe_7
		jmp not_bombe_7
		bombe_7:
		make_text_macro '7', area, x, y
		jmp final
		
		not_bombe_7:	
		make_text_macro '8', area, x, y
	
		
		
		
	final:
	
	
		push 0
        call time
        add esp,4
       
		push eax
        call srand
		add esp,4
		call rand 
		call rand 
	;	;;push eax
       ;; push format2
       ;; call [printf]
        ;;add esp,8
      
		mov ebx,100
		div ebx
		
	
	
	push edx
	push ik
	push offset format
	call printf
	add esp,12		

		
evt_timer:
	inc counter
	
afisare_litere:
	;afisam valoarea counter-ului curent (sute, zeci si unitati)
	mov ebx, 10
	mov eax, counter
	;cifra unitatilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 30, 10
	;cifra zecilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 20, 10
	;cifra sutelor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 10, 10

;linie_oriz_macro 300,300,200,000000h
;linie_vert_macro 300,300,200,000000h



mov eax,100
mov ecx,11
mamaliga:
	linie_oriz_macro 100,eax,400,000000h
	add eax,40
loop mamaliga ; dec ecx
mov eax,100

mov ecx,11
mamaliga_vert:
	linie_vert_macro eax,100,400,000000h
	add eax,40
loop mamaliga_vert ; dec ecx
	
	;make_text_macro 'B', area, 115, 110



cmp gmover,1
jl NOT_GAME_OVER

	make_text_macro ' ', area, 250, 30
	make_text_macro 'G', area, 260, 30
	make_text_macro 'A', area, 270, 30
	make_text_macro 'M', area, 280, 30
	make_text_macro 'E', area, 290, 30
	make_text_macro ' ', area, 300, 30
	make_text_macro 'O', area, 310, 30
	make_text_macro 'V', area, 320, 30
	make_text_macro 'E', area, 330, 30
	make_text_macro 'R', area, 340, 30
	make_text_macro ' ', area, 350, 30

jmp game_over

NOT_GAME_OVER:

	make_text_macro 'M', area, 250, 30
	make_text_macro 'I', area, 260, 30
	make_text_macro 'N', area, 270, 30
	make_text_macro 'E', area, 280, 30
	make_text_macro 'S', area, 290, 30
	make_text_macro 'W', area, 300, 30
	make_text_macro 'E', area, 310, 30
	make_text_macro 'E', area, 320, 30
	make_text_macro 'P', area, 330, 30
	make_text_macro 'E', area, 340, 30
	make_text_macro 'R', area, 350, 30
	
game_over:
	
fin_draw:
	popa
	mov esp, ebp
	pop ebp
	ret
draw endp

start:

	;alocam memorie pentru zona de desenat
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	call malloc
	add esp, 4
	mov area, eax
	;apelam functia de desenare a ferestrei
	; typedef void (*DrawFunc)(int evt, int x, int y);
	; void __cdecl BeginDrawing(const char *title, int width, int height, unsigned int *area, DrawFunc draw);
	push offset draw
	push area
	push area_height
	push area_width
	push offset window_title
	call BeginDrawing
	add esp, 20
	
	;terminarea programului
	push 0
	call exit
end start
