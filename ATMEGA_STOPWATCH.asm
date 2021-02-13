;***Регистр управления индикаторами - led_reg***
; 0,1,2 - биты выбора сегмента(всего 8 сегментов)
; 3,4,5,6 - выбор символа, где
;  0000 - "Р"
;  0001 - "0"
;  0010 - "1"
;  ....
;  1011 - "9"
; 7 - бит разрешения работы
;*************************************

;***Регистр управления ключами - key_reg***
; 0 - бит разрешения начала отсчета
; 1 - бит паузы
; 2 - бит начала отсчета сначала для все игроков
; 3 - бит готовности к сбросу
;******************************************

;***Регистр участников - party_reg ***
; 0 - первый участник
; 1 - второй участник
; 2 - третий участник
; 3 - четвертый участник
;*************************************

.include "m8515def.inc" ;файл определений для ATmega8515
.def temp = r16 		;временный регистр
.def party_reg = r19	;регистр участников
.def led_reg = r20 		;состояние регистра управления индикаторами
.def key_reg = r21		;разрешение работы секундомера
.def ms_reg = r22		;счетчик количества мс(от 0 до 100)
.def sec_reg = r23		;счетчик количества с
.def min_reg = r24		;счетчик количества мин
.def digl = r25 		;остаток от деления числа на 10
.def digh = r26			;частное от деления числа на 10
.def eel  = r27			;младший байт адреса EEPROM
.def eeh  = r28			;старший байт адреса EEPROM
.def eed  = r29			;байт данных EEPROM
.def addin	= r30		;инкремент адресса младшего байта EEPROM 
.equ XTAL = 1000000 	;тактовая частота
.equ baudrate = 4800
.equ bauddivider = XTAL/(16*baudrate)-1
.org $000
;***Векторы прерываний***
rjmp INIT 		   	;обработка сброса
.org $001
rjmp START_PRESSED 	;обработка внешнего прерывания INT0(START\LAP)
.org $002
rjmp RES_PRESSED 	;обработка внешнего прерывания INT1(RESET)
.org $00D
rjmp STOP_PRESSED	;обработка внешнего прерывания INT2(STOP)

;***Обработка прерываний***
START_PRESSED:
sbrc key_reg, 0	;пропускаем если бит начала отсчета равен 0
rjmp CHANGE_PARTY
clr key_reg	; устанавливаем регистр в 0
ldi key_reg, 1	; разрешаем начало отсчета
sbr led_reg, (1<<7) ;разрешаем работу индикатора
rjmp QUIT_SP	;выходим из прерывания
CHANGE_PARTY:
ldi temp, 3			;пропускаем следующую команду если номер игрока 4
cp party_reg, temp
brsh STOP_SP		;переходим по метке если >=
inc party_reg		;увеличиваем номер участника
clr temp			;очищаем временный регистр
;Запись данных в память
mov eed, ms_reg		;записываем результаты в память мс
rcall EEWrite		;запись
inc eel				;увеличиваем адрес
mov eed, sec_reg	;записываем результаты в память с
rcall EEWrite		;запись
inc eel				;увеличиваем адрес
mov eed, min_reg	;записываем результаты в память мин
rcall EEWrite		;запись
inc eel				;увеличиваем адрес
rjmp QUIT_SP		;выходим
STOP_SP:
sbrc key_reg, 3		; если установлен бит готовности к сбросу
rjmp CLEAN_SP		; сбрасываем
ldi key_reg, 3		; устанавливаем паузу и передаем данные
sbr key_reg, (1<<3)	; устанавливаем бит готовности к сбросу
;Запись данных в память
mov eed, ms_reg		;записываем результаты в память мс
rcall EEWrite		;запись
inc eel				;увеличиваем адрес
mov eed, sec_reg	;записываем результаты в память с
rcall EEWrite		;запись
inc eel				;увеличиваем адрес
mov eed, min_reg	;записываем результаты в память мин
rcall EEWrite		;запись
inc eel				;увеличиваем адрес
;Передаем данные
;**Читаем из памяти**
mov r15, r17		;сохраняем количество итераций
mov r14, r18
ldi addin, 2		;устанавливаем второй адрес
ldi eel, 2			;устанавливаем второй адрес
ldi r17, 1
CH_PR: ldi r18,3
CH_PR2:
cpi r18, 3			;сравниваем r18 с числом 3
brne SKIP_PARTY_NUM	;если не равны не выводим номер игрока
ldi eed, 80			;символ P
rcall uart_snt		;Передаем по юарт
mov eed, r17		;номер игрока
ldi temp, 48		;заносим слагаемое(с 48 начинаются цифры в ASCII)
add eed, temp		;складываем
rcall uart_snt		;Передаем по юарт
ldi eed, 46			;символ точки
rcall uart_snt		;Передаем по юарт
SKIP_PARTY_NUM:
rcall EERead		;читаем результат из памяти
mov temp, eed		;заносим прочитанный результат во временный регистр
rcall DIVIDE_NUM	;разделяем число
ldi temp, 48		;заносим слагаемое
add digl, temp		;переводим в ascii
add digh, temp
mov eed, digh		;заносим старшую цифру в регистр
rcall uart_snt		;Передаем по юарт
mov eed, digl		;заносим младшую цифру в регистр
rcall uart_snt		;Передаем по юарт
cpi r18, 1			;сравниваем шаг итерации с 1, чтобы не ставить двоеточие в лишний раз
breq SKIP_COLON		;переходим если равны
ldi eed, 58			;Двоеточие
rcall uart_snt		;Передаем по юарт
SKIP_COLON:
dec eel				;уменьшаем адрес
dec r18
brne CH_PR2			;переходим по метке
ldi eed, 32			;Пробел
rcall uart_snt		;Передаем по юарт
ldi temp, 3			;заносим слагаемое
add addin, temp		;увеличиваем адрес
mov eel, addin		;заносим адрес в регистр
inc r17				;увеличиваем шаг итерации на 1
cpi r17, 5			;сравниваем с 5
brlo CH_PR			;если меньше повторяем цикл
					;это нужно для отображения номера игрока

mov r17, r15		;возвращаем исходное значение в регистр
mov r18, r14
clr temp
rjmp QUIT_SP
CLEAN_SP:
clr eel				;очищаем младший байт адреса
clr party_reg		;очищаем номер участника и ожидаем разрешения на отсчет
clr key_reg
clr ms_reg
clr sec_reg
clr min_reg
clr temp
QUIT_SP:
reti

RES_PRESSED:
clr eel		; очищаем адрес младшего байта EEPROM
clr key_reg ; устанавливаем регистр в 0
ldi key_reg, (1<<2)	; устанавливаем 2 бит в 1
cbr led_reg, 0x7F	; сбрасываем бит разрешения работы индикатора(лог и)
;сбрасываем регистры времени и номера участника
clr ms_reg
clr sec_reg
clr min_reg
clr party_reg
reti

STOP_PRESSED:
ldi key_reg, 2	;устанавливаем паузу
reti

;***Подпрограмма разложения числа на две цифры***
DIVIDE_NUM:
;очищаем регистры хранения цифр
clr digl
clr digh
subi temp, 10	;вычитание 10 из исходного числа
brlt NEXTD		;если меньше 10 выходим по метке
LOOP:
inc digh	;инкремент левой цифры
subi temp, 10	;вычитание 10 из исходного числа
brge LOOP		;если >= 10 повторяем
NEXTD:
ldi digl,10	;заносим 10 в регистр правой цифры
add temp, digl	;восстанавливаем значение в регистре
mov digl, temp	;заносим остаток в регистр правой цифры
;inc digl		;увеличиваем на 1 т.к. символы начинаются с 1
;inc digh
clr temp		;очищаем временный регистр
ret

;***Подпрограмма индикации сегментов***
SET_NUM:
sbrs led_reg, 7 ; Проверяем бит разрешения индикации
rjmp GO_AWAY    ; Иначе выходим из подпрограммы
out PORTA, led_reg ; Зажигаем выбранный сегмент
GO_AWAY:
ret

;***Подпрограмма задержки 1.125мс***
DELAY: 
ldi r17,2
d1: ldi r18,186
d2: dec r18
brne d2
dec r17
brne d1
ret

;***Подпрограмма записи данных в EEPROM***
EEWrite:	
sbic	EECR,EEWE		; Ждем готовности памяти к записи. Крутимся в цикле
rjmp	EEWrite 		; до тех пор пока не очистится флаг EEWE
 
;cli						; Затем запрещаем прерывания.
out 	EEARL,R27 		; Загружаем адрес нужной ячейки
out 	EEARH,R28  		; старший и младший байт адреса
out 	EEDR,R29 		; и сами данные, которые нам нужно загрузить
 
sbi 	EECR,EEMWE		; взводим предохранитель
sbi 	EECR,EEWE		; записываем байт
;sei						; разрешаем прерывания
ret 					; возврат из процедуры

;***Подпрограмма чтения данных из EEPROM***
EERead:	
sbic 	EECR,EEWE		; Ждем пока будет завершена прошлая запись.
rjmp	EERead			; также крутимся в цикле.
out 	EEARL, R27		; загружаем адрес нужной ячейки
out  	EEARH, R28 		; его старшие и младшие байты
sbi 	EECR,EERE 		; Выставляем бит чтения
in 		R29, EEDR 		; Забираем из регистра данных результат
ret

;***Подпрограмма инициализации UART***
uart_init:	
ldi 	temp, low(bauddivider)
out 	UBRRL,temp
ldi 	temp, high(bauddivider)
out 	UBRRH,temp
 
ldi 	temp,0
out 	UCSRA, temp
; Прерывания запрещены, прием-передача разрешен.
ldi 	temp, (1<<RXEN)|(1<<TXEN)|(0<<RXCIE)|(0<<TXCIE)|(0<<UDRIE)
out 	UCSRB, temp	
 
; Формат кадра - 8 бит, пишем в регистр UCSRC, за это отвечает бит селектор
ldi 	temp, (1<<URSEL)|(1<<UCSZ0)|(1<<UCSZ1)
out 	UCSRC, temp
ret

; Подпрограмма отправки байта
uart_snt:	
sbis 	UCSRA,UDRE	; Пропуск если нет флага готовности
rjmp	uart_snt 	; ждем готовности - флага UDRE
 
out		UDR, eed	; шлем байт
ret					; Возврат

;***Инициализация МК***
INIT:
clr eel			; очищаем регистр младшего байта для записи EEPROM
clr eeh			; очищаем регистр старшего байта для записи EEPROM
clr eed			; очищаем регистр данных для записи EEPROM
clr party_reg	; записываем первого участника в регистр
clr key_reg		; очищаем регистр кнопок
clr ms_reg		; очищаем временные регистры
clr sec_reg
clr min_reg
ldi temp,Low(RAMEND) ; Инициализация стека
out SPL,temp
ldi temp,High(RAMEND)
out SPH,temp
rcall uart_init		;инициализируем юарт
ser temp ; инициализация
out DDRA,temp ; порта А на вывод
clr temp ;инициализация 2-ого и 3-ого выводов
out DDRD,temp ; порта PD на ввод
ldi temp,0x1C ;включение ‘подтягивающих’
out PORTD,temp ; резисторов порта PD
clr temp		; инициализация 1-го вывода
out DDRE, temp	; порта Е на ввод
inc temp		; включение
out PORTE, temp	; подтягивающих резисторов
ldi temp,(1<<INT0)|(1<<INT1)|(1<<INT2) ;разрешение прерывания INT0 и INT1 и INT2
out GICR,temp ; (6 бит GICR или GIMSK)
ldi temp,0x00 ;обработка прерывания
out MCUCR,temp ; по низкому уровню
sei ;глобальное разрешение прерываний

MAIN:
ldi led_reg, 0x80	;10000000 включен только бит разрешения
rcall SET_NUM	; устанавливаем символ P
rcall DELAY		; задержка
;****Установка номера участника****
mov led_reg, party_reg	;заносим номер участника
inc led_reg			;сдвигаем номер в символах(будет P1 вместо PP)
lsl led_reg		;сдвигаем 3 раза
lsl led_reg
lsl led_reg
inc led_reg 	;выставляем 2 сегмент
sbr led_reg, (1<<7)	;разрешаем отображение символов
rcall SET_NUM	; устанавливаем символ 1
rcall DELAY		; задержка
;****Выводим минуты****
;*****Левая цифра******
mov temp, min_reg	;загружаем количество минут во временный регистр
rcall DIVIDE_NUM
mov led_reg, digh	;загружаем частное от деления в регистр
lsl led_reg		;сдвигаем 3 раза
lsl led_reg
lsl led_reg
sbr led_reg, (1<<7)	;разрешаем отображение символов
ldi temp, 0x02		;устанавливаем третий сегмент
add led_reg, temp
rcall SET_NUM	; устанавливаем символ
rcall DELAY		; задержка
;******Правая цифра*****
mov led_reg, digl	;загружаем остаток от деления в регистр
lsl led_reg		;сдвигаем 3 раза
lsl led_reg
lsl led_reg
sbr led_reg, (1<<7)	;разрешаем отображение символов
ldi temp, 0x03		;устанавливаем четвертый сегмент
add led_reg, temp
rcall SET_NUM	; устанавливаем символ
rcall DELAY		; задержка
;****Выводим секунды****
;*****Левая цифра******
mov temp, sec_reg	;загружаем количество секунд во временный регистр
rcall DIVIDE_NUM
mov led_reg, digh	;загружаем частное от деления в регистр
lsl led_reg		;сдвигаем 3 раза
lsl led_reg
lsl led_reg
sbr led_reg, (1<<7)	;разрешаем отображение символов
ldi temp, 0x04		;устанавливаем третий сегмент
add led_reg, temp
rcall SET_NUM	; устанавливаем символ
rcall DELAY		; задержка
;******Правая цифра*****
mov led_reg, digl	;загружаем остаток от деления в регистр
lsl led_reg		;сдвигаем 3 раза
lsl led_reg
lsl led_reg
sbr led_reg, (1<<7)	;разрешаем отображение символов
ldi temp, 0x05		;устанавливаем четвертый сегмент
add led_reg, temp
rcall SET_NUM	; устанавливаем символ
rcall DELAY		; задержка
;****Выводим миллисекунды****
;*****Левая цифра******
mov temp, ms_reg	;загружаем количество мс во временный регистр
rcall DIVIDE_NUM
mov led_reg, digh	;загружаем частное от деления в регистр
lsl led_reg		;сдвигаем 3 раза
lsl led_reg
lsl led_reg
sbr led_reg, (1<<7)	;разрешаем отображение символов
ldi temp, 0x06		;устанавливаем третий сегмент
add led_reg, temp
rcall SET_NUM	; устанавливаем символ
rcall DELAY		; задержка
;******Правая цифра*****
mov led_reg, digl	;загружаем остаток от деления в регистр
lsl led_reg		;сдвигаем 3 раза
lsl led_reg
lsl led_reg
sbr led_reg, (1<<7)	;разрешаем отображение символов
ldi temp, 0x07		;устанавливаем четвертый сегмент
add led_reg, temp
rcall SET_NUM	; устанавливаем символ
rcall DELAY		; задержка
;***Считаем время***
COUNT:
sbrc key_reg, 1 ; проверяем, что не установлена пауза(0)
rjmp MAIN
sbrs key_reg, 0	; проверяем, что разрешено начало отсчета(1)
rjmp MAIN
ldi temp, 100	;загружаем предельное значение мс
inc ms_reg		;считаем миллисекунды
cpse ms_reg, temp	;пропускаем следующую команду если не равны
rjmp NEXT
clr ms_reg		;обнуляем регистр мс
ldi temp, 60	;загружаем предельное значение с
inc sec_reg ;считаем секунды
cpse sec_reg, temp	;пропускаем следующую команду если не равны
rjmp NEXT
clr sec_reg	;очищаем регистр с
ldi temp, 60	;загружаем предельное значение мин
inc min_reg ;считаем минуты
cpse min_reg, temp	;пропускаем следующую команду если не равны
rjmp NEXT
clr min_reg	;при превышении счета в 60 минут происходит обнуление минут
NEXT:
rjmp MAIN
