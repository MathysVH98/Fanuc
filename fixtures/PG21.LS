/PROG  PG21
/ATTR
OWNER		= MNEDITOR;
COMMENT		= "PICK HEAVY DUTY";
PROG_SIZE	= 12956;
CREATE		= DATE 25-08-24  TIME 21:14:08;
MODIFIED	= DATE 26-09-17  TIME 06:01:42;
FILE_NAME	= PG14;
VERSION		= 0;
LINE_COUNT	= 550;
MEMORY_SIZE	= 13648;
PROTECT		= READ_WRITE;
TCD:  STACK_SIZE	= 0,
      TASK_PRIORITY	= 50,
      TIME_SLICE	= 0,
      BUSY_LAMP_OFF	= 0,
      ABORT_REQUEST	= 0,
      PAUSE_REQUEST	= 0;
DEFAULT_GROUP	= 1,*,*,*,*;
CONTROL_CODE	= 00000000 00000000;
LOCAL_REGISTERS	= 0,0,0;
/APPL
  SPOT : TRUE ; 

AUTO_SINGULARITY_HEADER;
  ENABLE_SINGULARITY_AVOIDANCE   : FALSE;
  SPOT Welding Equipment Number : 1 ;

PLTZ_MODE_HEADER;
 PLTZ_MODE_ENABLE   : FALSE;
 J4TURN  : ZERORAD;
 ORIENT  : DOWNWARDS;
/MN
   1:  !***************************** ;
   2:  ! MH PG21 - HD ;
   3:  !***************************** ;
   4:   ;
   5:  !Program Number Feedback ;
   6:  GO[10]=21 ;
   7:   ;
   8:  !If Part Present and Gripper ;
   9:  ! Closed, GO set Part Down ;
  10:  IF DI[67]=ON AND DI[74]=ON,JMP LBL[10] ;
  11:   ;
  12:  !-------------------------------- ;
  13:  !Set Robot Payload WITHOUT PART ;
  14:  PAYLOAD[1] ;
  15:   ;
  16:  !Setup App Specific Outputs ;
  17:  ! Runs HOME_IO ;
  18:   ;
  19:  !Move to Home ;
  20:  GO TO HOME POS    ;
  21:   ;
  22:  ! Move to pounce position ;
  23:  GO TO POUNCE    ;
  24:   ;
  25:  !Clr to Adv Xfer ;
  26:  DO[954]=ON ;
  27:   ;
  28:  !Clr to Ret Xfer ;
  29:  DO[955]=ON ;
  30:   ;
  31:  !Clr to Unclamp ;
  32:  DO[956]=OFF ;
  33:   ;
  34:  !-------------------------------- ;
  35:  LBL[33:Loop Back] ;
  36:   ;
  37:  ! Turn ON Robot in LOOP ;
  38:  //DO[24]=ON ;
  39:   ;
  40:  !-------------------------------- ;
  41:  !Wait Continue from Pounce ;
  42:  ! or Return to Home ;
  43:  WAIT DI[9]=ON OR DI[13]=ON    ;
  44:   ;
  45:  ! Turn OFF Robot in LOOP ;
  46:  DO[24]=OFF ;
  47:  !If Return to Home ;
  48:  ! jump to LB[13] ;
  49:  IF DI[13]=ON,JMP LBL[13] ;
  50:   ;
  51:  !If Continue from Pounce ;
  52:  ! jump to LB[9] ;
  53:  IF DI[9]=ON AND DI[1512]=ON,JMP LBL[9] ;
  54:   ;
  55:  JMP LBL[33] ;
  56:   ;
  57:  !-------------------------------- ;
  58:  !Continue from Pounce ;
  59:  LBL[9] ;
  60:   ;
  61:  !Clr to Return Xfer ;
  62:  DO[955]=OFF ;
  63:   ;
  64:  !Clr to Adv Xfer ;
  65:  DO[954]=OFF ;
  66:   ;
  67:  !Clr to Unclamp ;
  68:  DO[956]=OFF ;
  69:   ;
  70:  !******************************* ;
  71:  !PICKUP PATH ;
  72:  !******************************* ;
  73:   ;
  74:  !Turn ON Robot in LOOP ;
  75:  //DO[24]=ON ;
  76:   ;
  77:  !Wait for Clear to Pickup ;
  78:  WAIT DI[94]=ON    ;
  79:   ;
  80:  LBL[120:Decide Pick 1or2] ;
  81:  //J P[23] 100% CNT50    ;
  82:J P[38] 100% FINE    ;
  83:  !Wait for Pick 1 or Pick 2 ;
  84:  WAIT DI[41]=ON OR DI[42]=ON    ;
  85:  IF DI[42]=ON,JMP LBL[109] ;
  86:  IF DI[41]=ON,JMP LBL[110] ;
  87:   ;
  88:  LBL[109:GOTO PICK2] ;
  89:  !******************************* ;
  90:  !PICKUP 2 PATH - LH ;
  91:  !******************************* ;
  92:   ;
  93:  !Turn OFF Robot in LOOP ;
  94:  DO[24]=OFF ;
  95:   ;
  96:  !Enter Zone 1 ;
  97:  ENTER ZONE(1) ;
  98:   ;
  99:  !Check Clamps OPENED ;
 100:  WAIT DI[73]=ON    ;
 101:  !Move to Pickup Position 2 ;
 102:   ;
 103:J P[1] 100% FINE    ;
 104:   ;
 105:  //!DECIDE BAY 1-4 LH HD Trolley ;
 106:  //LBL[*140:LHTrlyBay1-4] ;
 107:   ;
 108:  //DO[43]=OFF ;
 109:  //DO[44]=OFF ;
 110:  //DO[45]=OFF ;
 111:  //DO[46]=OFF ;
 112:  //WAIT DI[43]=ON OR DI[44]=ON OR DI[45]=ON OR DI[46]=ON    ;
 113:  //IF DI[43]=ON,JMP LBL[141] ;
 114:  //IF DI[44]=ON,JMP LBL[142] ;
 115:  //IF DI[45]=ON,JMP LBL[143] ;
 116:  //IF DI[46]=ON,JMP LBL[144] ;
 117:   ;
 118:  !GoToPick2 ;
 119:  LBL[141:Pick2] ;
 120:J P[2] 100% FINE    ;
 121:   ;
 122:  !Confirm LH Part In Station ;
 123:  DO[43]=ON ;
 124:  WAIT   1.00(sec) ;
 125:  DO[43]=OFF ;
 126:  !If PartPresent  Continue ;
 127:  !Else Check Next Position ;
 128:  IF DI[43]=OFF,JMP LBL[140] ;
 129:  DO[43]=OFF ;
 130:   ;
 131:  //!CALL VISION LH PART BAY1 ;
 132:  //J P[10] 100% FINE    ;
 133:  //CALL VIS_LHPART_BAY1    ;
 134:  //IF DI[93]=ON,JMP LBL[11] ;
 135:  JMP LBL[121] ;
 136:   ;
 137:  //!GoToLHTrolley Bay 2 ;
 138:  //LBL[*142:LHPrtTrly-Bay2] ;
 139:  //J P[3] 100% FINE    ;
 140:   ;
 141:  //!Confirm LH Part In Bay2 ;
 142:  //DO[44]=ON ;
 143:  //WAIT   1.00(sec) ;
 144:  //DO[44]=OFF ;
 145:  //!If PartPresent  Continue ;
 146:  //!Else Check Next Position ;
 147:  //IF DI[44]=OFF,JMP LBL[140] ;
 148:  //DO[44]=OFF ;
 149:   ;
 150:  //!CALL VISION LH PART BAY2 ;
 151:  //J P[8] 100% FINE    ;
 152:  //CALL VIS_LHPART_BAY2    ;
 153:  //IF DI[93]=ON,JMP LBL[11] ;
 154:  //JMP LBL[121] ;
 155:   ;
 156:  //!GoToLHTrolley Bay 3 ;
 157:  //LBL[*143:LHPrtTrly-Bay3] ;
 158:  //J P[4] 100% FINE    ;
 159:   ;
 160:  //!Confirm LH Part In Bay3 ;
 161:  //DO[45]=ON ;
 162:  //WAIT   2.00(sec) ;
 163:  //DO[45]=OFF ;
 164:  //!If PartPresent  Continue ;
 165:  //!Else Check Next Position ;
 166:  //IF DI[45]=OFF,JMP LBL[140] ;
 167:  //IF DI[294]=OFF,JMP LBL[140] ;
 168:  //DO[45]=OFF ;
 169:   ;
 170:  //!CALL VISION LH PART BAY3 ;
 171:  //CALL VIS_LHPART_BAY3    ;
 172:  //IF DI[93]=ON,JMP LBL[11] ;
 173:  //JMP LBL[121] ;
 174:   ;
 175:  //!GoToLHTrolley Bay 4 ;
 176:  //LBL[*144:LHPrtTrly-Bay4] ;
 177:  //J P[5] 100% FINE    ;
 178:   ;
 179:  //!Confirm LHPart In Bay4 ;
 180:  //DO[46]=ON ;
 181:  //WAIT   1.00(sec) ;
 182:  //DO[46]=OFF ;
 183:  //!If PartPresent  Continue ;
 184:  //!Else Check Next Position ;
 185:  //IF DI[46]=OFF,JMP LBL[140] ;
 186:  //DO[46]=OFF ;
 187:   ;
 188:  //!CALL VISION LH PART BAY4 ;
 189:  //CALL VIS_LHPART_BAY4    ;
 190:  //IF DI[93]=ON,JMP LBL[11] ;
 191:  //JMP LBL[121] ;
 192:   ;
 193:  LBL[121:PICK LH PART] ;
 194:  //L P[6] 750mm/sec FINE    ;
 195:  !AT PICK POS2 ;
 196:  DO[50]=ON ;
 197:  PAYLOAD[2] ;
 198:  WAIT DI[67]=ON    ;
 199:  !Exit pick 2 ;
 200:   ;
 201:  //!Store Pos in PR Move Up ;
 202:  //PR[10]=LPOS    ;
 203:  //PR[10,3]=PR[10,3]+30    ;
 204:   ;
 205:  //PR[10,1]=PR[10,1]-3    ;
 206:  //PR[10,5]=3    ;
 207:  //PR[10,4]=179.899    ;
 208:L PR[10] 750mm/sec FINE    ;
 209:   ;
 210:  //PR[10]=LPOS    ;
 211:  //PR[10,2]=PR[10,2]+7    ;
 212:  //PR[10,3]=PR[10,3]+R[1]-177    ;
 213:  //PR[10,5]=(-2.21)    ;
 214:L PR[10] 750mm/sec FINE    ;
 215:   ;
 216:  DO[50]=ON ;
 217:  WAIT DI[50]=ON    ;
 218:  DO[50]=OFF ;
 219:   ;
 220:  !MOVE TO EXIT PICK ZONE ;
 221:   ;
 222:J P[25] 100% CNT100    ;
 223:J P[7] 100% CNT100    ;
 224:J P[9] 100% FINE    ;
 225:   ;
 226:  !EXIT ZONE 1 ;
 227:  EXIT ZONE(1) ;
 228:   ;
 229:  JMP LBL[114] ;
 230:   ;
 231:  LBL[114:MOVE TO DROP 2] ;
 232:   ;
 233:  !MOVE TO DROP 2 - LH PART ;
 234:  !ENTER ZONE 2 ;
 235:  ENTER ZONE(2) ;
 236:   ;
 237:  !ENTER ZONE 6 With 040R01 ;
 238:  ENTER ZONE(6) ;
 239:   ;
 240:J P[12] 100% FINE    ;
 241:J P[13] 100% CNT5    ;
 242:  PAYLOAD[1] ;
 243:L P[15] 750mm/sec FINE    ;
 244:  CALL CLP1_OPN    ;
 245:   ;
 246:  !ROBOT AT DROP 2 ;
 247:  DO[60]=ON ;
 248:   ;
 249:  JMP LBL[112] ;
 250:   ;
 251:  LBL[110:Goto Pick1 RH Pt] ;
 252:  !******************************* ;
 253:  !PICKUP 1 PATH - RH Part ;
 254:  !******************************* ;
 255:   ;
 256:  !Turn OFF Robot in LOOP ;
 257:  DO[24]=OFF ;
 258:   ;
 259:  !Enter Zone 4 - RH Part Trolly ;
 260:  ENTER ZONE(4) ;
 261:   ;
 262:  !Check Clamps OPENED ;
 263:  WAIT DI[73]=ON    ;
 264:   ;
 265:  !Move to RH Part Trolley ;
 266:J P[16] 100% FINE    ;
 267:   ;
 268:  !DECIDE RH Part Trolley Bay 1-4 ;
 269:  LBL[150:LargeTrlyBay1-3] ;
 270:  DO[43]=OFF ;
 271:  DO[44]=OFF ;
 272:  DO[45]=OFF ;
 273:  DO[46]=OFF ;
 274:  DO[47]=OFF ;
 275:   ;
 276:   ;
 277:  WAIT DI[43]=ON OR DI[44]=ON OR DI[45]=ON OR DI[46]=ON    ;
 278:  IF DI[43]=ON,JMP LBL[151] ;
 279:  IF DI[44]=ON,JMP LBL[152] ;
 280:  IF DI[45]=ON,JMP LBL[153] ;
 281:  IF DI[46]=ON,JMP LBL[154] ;
 282:  IF DI[47]=ON,JMP LBL[155] ;
 283:   ;
 284:  !GoToLHPartTrolley Bay 1 ;
 285:  LBL[151:RHPrtTrly-Bay1] ;
 286:  !Reconfigure Robot Joints ;
 287:J P[22] 100% FINE    ;
 288:  !Confirm RH Part In Bay1 ;
 289:  DO[43]=ON ;
 290:  WAIT   1.00(sec) ;
 291:  DO[43]=OFF ;
 292:  !If PartPresent  Continue ;
 293:  !Else Check Next Position ;
 294:  IF DI[43]=OFF,JMP LBL[150] ;
 295:  DO[43]=OFF ;
 296:   ;
 297:  !CALL VISION RH PART ;
 298:  CALL VIS_RHPART_BAY1    ;
 299:  IF DI[93]=ON,JMP LBL[12] ;
 300:  JMP LBL[122] ;
 301:   ;
 302:  !GoToLHTrolley Bay 2 ;
 303:  LBL[152:RHPrtTrly-Bay2] ;
 304:   ;
 305:J P[19] 100% FINE    ;
 306:   ;
 307:  !Confirm RHPart In Bay2 ;
 308:  DO[44]=ON ;
 309:  WAIT   1.00(sec) ;
 310:  DO[44]=OFF ;
 311:  !If PartPresent  Continue ;
 312:  !Else Check Next Position ;
 313:  IF DI[44]=OFF,JMP LBL[150] ;
 314:  DO[44]=OFF ;
 315:   ;
 316:  !CALL VISION RH PART TROLLEY ;
 317:  CALL VIS_RHPART_BAY2    ;
 318:  IF DI[93]=ON,JMP LBL[12] ;
 319:  JMP LBL[122] ;
 320:   ;
 321:  !GoToRHTrolley Bay 3 ;
 322:  LBL[153:RHPrtTrly-Bay3] ;
 323:   ;
 324:J P[28] 100% FINE    ;
 325:   ;
 326:  !Confirm RHPart In Bay3 ;
 327:  DO[45]=ON ;
 328:  WAIT   2.00(sec) ;
 329:  DO[45]=OFF ;
 330:  !If PartPresent  Continue ;
 331:  !Else Check Next Position ;
 332:  IF DI[45]=OFF,JMP LBL[150] ;
 333:  DO[45]=OFF ;
 334:  //IF DI[294]=OFF,JMP LBL[150] ;
 335:   ;
 336:  !CALL VISION RH PART TROLLEY ;
 337:  CALL VIS_RHPART_BAY3    ;
 338:  IF DI[93]=ON,JMP LBL[12] ;
 339:  JMP LBL[122] ;
 340:   ;
 341:  !GoToRHTrolley Bay 4 ;
 342:  LBL[154:RHPrtTrly-Bay4] ;
 343:   ;
 344:J P[39] 100% FINE    ;
 345:   ;
 346:  !Confirm RHPart In Bay4 ;
 347:  DO[46]=ON ;
 348:  WAIT   1.00(sec) ;
 349:  DO[46]=OFF ;
 350:  !If PartPresent  Continue ;
 351:  !Else Check Next Position ;
 352:  IF DI[46]=OFF,JMP LBL[150] ;
 353:  DO[46]=OFF ;
 354:   ;
 355:  !CALL VISION RH PART TROLLEY ;
 356:  CALL VIS_RHPART_BAY4    ;
 357:  IF DI[93]=ON,JMP LBL[12] ;
 358:  JMP LBL[122] ;
 359:   ;
 360:  !GoToRHTrolley Bay 5 ;
 361:  LBL[155:RHPrtTrly-Bay5] ;
 362:   ;
 363:J P[...] 100% FINE    ;
 364:   ;
 365:  !Confirm RHPart In Bay5 ;
 366:  DO[47]=ON ;
 367:  WAIT   1.00(sec) ;
 368:  DO[47]=OFF ;
 369:  !If PartPresent  Continue ;
 370:  !Else Check Next Position ;
 371:  IF DI[47]=OFF,JMP LBL[150] ;
 372:  DO[47]=OFF ;
 373:   ;
 374:  !CALL VISION RH PART TROLLEY ;
 375:  CALL VIS_RHPART_BAY5    ;
 376:  IF DI[93]=ON,JMP LBL[12] ;
 377:  JMP LBL[122] ;
 378:   ;
 379:   ;
 380:  LBL[122:PICK RH PART] ;
 381:  //L P[17] 100mm/sec FINE    ;
 382:  !AT PICK POS2 ;
 383:  //DO[50]=ON ;
 384:  PAYLOAD[3] ;
 385:  WAIT DI[67]=ON    ;
 386:  !Exit pick 2 ;
 387:  !Store Pos in PR Move Up ;
 388:  PR[10]=LPOS    ;
 389:  PR[10,1]=PR[10,1]-3    ;
 390:  PR[10,3]=PR[10,3]+10    ;
 391:  PR[10,4]=(-179.899)    ;
 392:  PR[10,5]=(-6)    ;
 393:L PR[10] 750mm/sec FINE    ;
 394:  PR[10,2]=PR[10,2]+8    ;
 395:  PR[10,3]=PR[10,3]+R[1]-78    ;
 396:L PR[10] 750mm/sec FINE    ;
 397:   ;
 398:  DO[49]=ON ;
 399:  WAIT DI[49]=ON    ;
 400:  DO[49]=OFF ;
 401:   ;
 402:  !EXIT ZONE 4 ;
 403:  EXIT ZONE(4) ;
 404:  JMP LBL[115] ;
 405:   ;
 406:  LBL[115:GOTO DROP 1] ;
 407:   ;
 408:J P[11] 100% FINE    ;
 409:J P[14] 100% FINE    ;
 410:   ;
 411:  !MOVE TO DROP 1 - RH PART ;
 412:  !ENTER ZONE 2 ;
 413:  //ENTER ZONE(2) ;
 414:   ;
 415:  !ENTER ZONE 6 With 040R01 ;
 416:  ENTER ZONE(6) ;
 417:   ;
 418:J P[30] 100% FINE    ;
 419:L P[37] 750mm/sec CNT100    ;
 420:L P[33] 750mm/sec CNT50    ;
 421:L P[34] 750mm/sec FINE    ;
 422:  PAYLOAD[1] ;
 423:L P[35] 750mm/sec FINE    ;
 424:  !ROBOT AT DROP 1 ;
 425:  DO[59]=ON ;
 426:  CALL CLP1_OPN    ;
 427:  JMP LBL[113] ;
 428:   ;
 429:  LBL[112:Exit Drop 2] ;
 430:  !CLAMP REPO ;
 431:  //DO[47]=ON ;
 432:  //WAIT DI[47]=ON    ;
 433:  //DO[47]=OFF ;
 434:  WAIT DI[60]=ON    ;
 435:   ;
 436:  !Exit Drop 2 - LH Part ;
 437:   ;
 438:L P[36] 750mm/sec FINE    ;
 439:   ;
 440:  !WAIT PART RELEASED ;
 441:  WAIT DI[97]=ON    ;
 442:  DO[59]=OFF ;
 443:  DO[60]=OFF ;
 444:   ;
 445:J P[27] 100% CNT20    ;
 446:   ;
 447:  !EXIT ZONE 2 ;
 448:  //EXIT ZONE(2) ;
 449:  !EXIT ZONE 6 With 040R01 ;
 450:  EXIT ZONE(6) ;
 451:   ;
 452:J P[24] 100% FINE    ;
 453:   ;
 454:  !GOTO Pick 1 ;
 455:  JMP LBL[110] ;
 456:   ;
 457:  LBL[113:Exit Drop 1] ;
 458:  !CLAMP REPO ;
 459:  //DO[47]=ON ;
 460:  //WAIT DI[47]=ON    ;
 461:  //DO[47]=OFF ;
 462:  WAIT DI[59]=ON    ;
 463:   ;
 464:  !Exit Drop 1 - RH Part ;
 465:   ;
 466:L P[42] 750mm/sec FINE    ;
 467:   ;
 468:  !WAIT PART RELEASED ;
 469:  WAIT DI[97]=ON    ;
 470:  DO[59]=OFF ;
 471:  DO[60]=OFF ;
 472:   ;
 473:J P[43] 100% CNT100    ;
 474:J P[21] 100% CNT10    ;
 475:   ;
 476:  !EXIT ZONE 2 ;
 477:  EXIT ZONE(2) ;
 478:  !EXIT ZONE 6 With 040R01 ;
 479:  EXIT ZONE(6) ;
 480:   ;
 481:J P[47] 100% CNT20    ;
 482:   ;
 483:  //JMP LBL[109] ;
 484:  JMP LBL[13] ;
 485:   ;
 486:  LBL[11:Abort Pick] ;
 487:  !Wait for no parts ;
 488:  !present ;
 489:  WAIT DI[66]=ON    ;
 490:  WAIT DI[73]=ON    ;
 491:  PR[10]=LPOS    ;
 492:  PR[10,3]=100    ;
 493:L PR[10] 750mm/sec FINE    ;
 494:   ;
 495:J P[49] 100% FINE    ;
 496:J P[56] 100% CNT100    ;
 497:   ;
 498:  !EXIT ZONE 1 ;
 499:  EXIT ZONE(1) ;
 500:   ;
 501:  JMP LBL[13] ;
 502:   ;
 503:  LBL[12:Abort Pick] ;
 504:  !Wait for no parts ;
 505:  !present ;
 506:  WAIT DI[66]=ON    ;
 507:  WAIT DI[73]=ON    ;
 508:  PR[10]=LPOS    ;
 509:  PR[10,3]=100    ;
 510:L PR[10] 750mm/sec FINE    ;
 511:   ;
 512:J P[18] 100% FINE    ;
 513:J P[20] 100% CNT100    ;
 514:   ;
 515:  !EXIT ZONE 1 ;
 516:  EXIT ZONE(1) ;
 517:   ;
 518:  JMP LBL[13] ;
 519:   ;
 520:  !-------------------------------- ;
 521:  LBL[10:Skip Pickup ] ;
 522:   ;
 523:  !-------------------------------- ;
 524:  !Clr to Return Xfer ;
 525:  DO[955]=OFF ;
 526:   ;
 527:  !Clr to Adv Xfer ;
 528:  DO[954]=OFF ;
 529:   ;
 530:  !Clr to Unclamp ;
 531:  DO[956]=OFF ;
 532:   ;
 533:  !Set Robot Payload WITH PART ;
 534:  PAYLOAD[1] ;
 535:   ;
 536:  !-------------------------------- ;
 537:  !If Skip Rivet Routine ;
 538:  IF DI[354]=ON,JMP LBL[222] ;
 539:   ;
 540:  !If Return to Home ;
 541:  ! jump to LB[13] ;
 542:   ;
 543:  LBL[13:Return to Home ] ;
 544:  !-------------------------------- ;
 545:  !Move to Home ;
 546:  GO TO HOME POS    ;
 547:   ;
 548:  !Program Number Feedback Reset ;
 549:  GO[10]=0 ;
 550:   ;
/POS
P[1]{
   GP1:
	UF : 1, UT : 1,	
	J1=  -103.295 deg,	J2=    -9.362 deg,	J3=   -27.832 deg,
	J4=      .354 deg,	J5=   -63.514 deg,	J6=  -257.975 deg
};
P[2]{
   GP1:
	UF : 1, UT : 1,		CONFIG : 'N U T, 0, 0, -1',
	X =  -201.857  mm,	Y =  -803.356  mm,	Z =   173.526  mm,
	W =  -178.617 deg,	P =      .026 deg,	R =    -1.106 deg
};
P[3]{
   GP1:
	UF : 1, UT : 1,		CONFIG : 'N U T, 0, 0, -1',
	X =  -189.750  mm,	Y = -1054.317  mm,	Z =   173.542  mm,
	W =  -178.630 deg,	P =      .025 deg,	R =    -1.108 deg
};
P[4]{
   GP1:
	UF : 1, UT : 1,		CONFIG : 'N U T, 0, 0, -1',
	X =  -189.890  mm,	Y = -1320.794  mm,	Z =   173.542  mm,
	W =  -178.743 deg,	P =     -.000 deg,	R =    -1.108 deg
};
P[5]{
   GP1:
	UF : 1, UT : 1,	
	J1=   -98.044 deg,	J2=    47.156 deg,	J3=   -11.568 deg,
	J4=      .128 deg,	J5=   -79.477 deg,	J6=  -263.089 deg
};
P[6]{
   GP1:
	UF : 1, UT : 1,	
	J1=  -106.710 deg,	J2=    79.290 deg,	J3=   -48.830 deg,
	J4=     0.000 deg,	J5=   -41.170 deg,	J6=   106.170 deg
};
P[7]{
   GP1:
	UF : 1, UT : 1,		CONFIG : 'N U T, 0, 0, 0',
	X =    29.353  mm,	Y =  -731.049  mm,	Z =   485.946  mm,
	W =   176.669 deg,	P =    -4.837 deg,	R =  -111.467 deg
};
P[8]{
   GP1:
	UF : 1, UT : 1,		CONFIG : 'N U T, 0, 0, -1',
	X =  -189.750  mm,	Y = -1054.317  mm,	Z =   173.542  mm,
	W =  -178.630 deg,	P =      .025 deg,	R =    -1.108 deg
};
P[9]{
   GP1:
	UF : 1, UT : 1,		CONFIG : 'N U T, 0, 0, 0',
	X =   666.909  mm,	Y =  -152.775  mm,	Z =   621.203  mm,
	W =  -179.807 deg,	P =    -1.608 deg,	R =   -97.791 deg
};
P[10]{
   GP1:
	UF : 1, UT : 1,		CONFIG : 'N U T, 0, 0, -1',
	X =  -201.857  mm,	Y =  -803.356  mm,	Z =   173.526  mm,
	W =  -178.617 deg,	P =      .026 deg,	R =    -1.106 deg
};
P[11]{
   GP1:
	UF : 1, UT : 1,		CONFIG : 'N U T, 0, 0, 0',
	X =   290.058  mm,	Y =  -643.048  mm,	Z =   566.088  mm,
	W =   179.497 deg,	P =    -5.986 deg,	R =    24.066 deg
};
P[12]{
   GP1:
	UF : 1, UT : 1,		CONFIG : 'N U T, 0, 0, 0',
	X =   666.909  mm,	Y =  -152.775  mm,	Z =   621.203  mm,
	W =  -179.807 deg,	P =    -1.608 deg,	R =   -97.791 deg
};
P[13]{
   GP1:
	UF : 1, UT : 1,		CONFIG : 'N U T, 0, 0, 0',
	X =   616.666  mm,	Y =   933.039  mm,	Z =  -204.605  mm,
	W =   179.804 deg,	P =    -4.162 deg,	R =   -87.865 deg
};
P[14]{
   GP1:
	UF : 1, UT : 1,		CONFIG : 'N U T, 0, 0, 0',
	X =   639.102  mm,	Y =  -226.681  mm,	Z =   726.006  mm,
	W =   176.379 deg,	P =    -5.584 deg,	R =    67.197 deg
};
P[15]{
   GP1:
	UF : 1, UT : 1,	
	J1=    57.339 deg,	J2=    29.132 deg,	J3=   -57.239 deg,
	J4=     3.734 deg,	J5=   -36.350 deg,	J6=  -148.289 deg
};
P[16]{
   GP1:
	UF : 1, UT : 1,		CONFIG : 'N U T, 0, 0, -1',
	X =  2164.682  mm,	Y =   228.783  mm,	Z =   393.908  mm,
	W =   175.569 deg,	P =    21.286 deg,	R =  -176.483 deg
};
P[17]{
   GP1:
	UF : 1, UT : 1,		CONFIG : 'N U T, 0, 0, 0',
	X =   276.412  mm,	Y = -1589.555  mm,	Z =   140.617  mm,
	W =  -179.368 deg,	P =     2.210 deg,	R =      .725 deg
};
P[18]{
   GP1:
	UF : 1, UT : 1,		CONFIG : 'N U T, 0, 0, -1',
	X =    71.479  mm,	Y =  -896.242  mm,	Z =   490.013  mm,
	W =   164.280 deg,	P =     7.775 deg,	R =    33.288 deg
};
P[19]{
   GP1:
	UF : 1, UT : 1,		CONFIG : 'N U T, 0, 0, 0',
	X =   142.989  mm,	Y = -1060.636  mm,	Z =   173.543  mm,
	W =  -178.971 deg,	P =      .006 deg,	R =     -.368 deg
};
P[20]{
   GP1:
	UF : 1, UT : 1,		CONFIG : 'N U T, 0, 0, -1',
	X =  -648.689  mm,	Y =  -502.707  mm,	Z =   172.752  mm,
	W =  -178.326 deg,	P =    -2.211 deg,	R =   -22.693 deg
};
P[21]{
   GP1:
	UF : 1, UT : 1,		CONFIG : 'N U T, 0, 0, 0',
	X =   683.077  mm,	Y =    85.128  mm,	Z =   582.691  mm,
	W =  -174.659 deg,	P =    -1.095 deg,	R =  -119.023 deg
};
P[22]{
   GP1:
	UF : 1, UT : 1,		CONFIG : 'N U T, 0, 0, 0',
	X =   140.830  mm,	Y =  -799.036  mm,	Z =   173.543  mm,
	W =  -178.059 deg,	P =      .011 deg,	R =     -.368 deg
};
P[23]{
   GP1:
	UF : 1, UT : 1,		CONFIG : 'N U T, 0, 0, 0',
	X =  -539.362  mm,	Y =  -346.644  mm,	Z =   221.192  mm,
	W =  -179.345 deg,	P =     -.704 deg,	R =   140.653 deg
};
P[24]{
   GP1:
	UF : 1, UT : 1,		CONFIG : 'N U T, 0, 0, 0',
	X =    94.022  mm,	Y =  -590.984  mm,	Z =   594.215  mm,
	W =  -176.292 deg,	P =      .570 deg,	R =     -.342 deg
};
P[25]{
   GP1:
	UF : 1, UT : 1,		CONFIG : 'N U T, 0, 0, -1',
	X =  -478.836  mm,	Y =  -999.976  mm,	Z =   224.288  mm,
	W =  -178.509 deg,	P =    -2.210 deg,	R =      .635 deg
};
P[27]{
   GP1:
	UF : 1, UT : 1,		CONFIG : 'N U T, 0, 0, 0',
	X =   681.433  mm,	Y =   125.681  mm,	Z =   626.608  mm,
	W =  -179.492 deg,	P =    -1.999 deg,	R =   -75.654 deg
};
P[28]{
   GP1:
	UF : 1, UT : 1,		CONFIG : 'N U T, 0, 0, 0',
	X =   150.961  mm,	Y = -1308.314  mm,	Z =   173.542  mm,
	W =  -179.427 deg,	P =      .003 deg,	R =     -.368 deg
};
P[30]{
   GP1:
	UF : 1, UT : 1,	
	J1=   -23.070 deg,	J2=   -18.622 deg,	J3=     9.374 deg,
	J4=    -5.618 deg,	J5=   -95.735 deg,	J6=    89.351 deg
};
P[33]{
   GP1:
	UF : 1, UT : 1,	
	J1=    41.159 deg,	J2=    35.769 deg,	J3=   -34.140 deg,
	J4=     4.206 deg,	J5=   -59.620 deg,	J6=    47.774 deg
};
P[34]{
   GP1:
	UF : 1, UT : 1,	
	J1=    41.994 deg,	J2=    42.908 deg,	J3=   -37.505 deg,
	J4=     4.297 deg,	J5=   -56.316 deg,	J6=    47.222 deg
};
P[35]{
   GP1:
	UF : 1, UT : 1,		CONFIG : 'N U T, 0, 0, 0',
	X =  1098.971  mm,	Y =   949.135  mm,	Z =  -322.279  mm,
	W =  -179.457 deg,	P =     5.147 deg,	R =    91.743 deg
};
P[36]{
   GP1:
	UF : 1, UT : 1,		CONFIG : 'N U T, 0, 0, 0',
	X =   616.341  mm,	Y =   931.846  mm,	Z =  -146.149  mm,
	W =   179.798 deg,	P =    -2.798 deg,	R =   -88.660 deg
};
P[37]{
   GP1:
	UF : 1, UT : 1,		CONFIG : 'N U T, 0, 0, 0',
	X =   767.539  mm,	Y =   373.784  mm,	Z =   598.098  mm,
	W =  -177.939 deg,	P =    -5.413 deg,	R =    77.965 deg
};
P[38]{
   GP1:
	UF : 1, UT : 1,		CONFIG : 'N U T, 0, 0, -1',
	X =  2164.682  mm,	Y =   228.783  mm,	Z =   393.908  mm,
	W =   175.569 deg,	P =    21.286 deg,	R =  -176.483 deg
};
P[39]{
   GP1:
	UF : 1, UT : 1,		CONFIG : 'N U T, 0, 0, 0',
	X =   143.991  mm,	Y = -1587.192  mm,	Z =   173.542  mm,
	W =  -178.593 deg,	P =      .008 deg,	R =     -.368 deg
};
P[42]{
   GP1:
	UF : 1, UT : 1,		CONFIG : 'N U T, 0, 0, 0',
	X =  1100.847  mm,	Y =   953.864  mm,	Z =  -142.355  mm,
	W =  -179.499 deg,	P =     5.156 deg,	R =    91.202 deg
};
P[43]{
   GP1:
	UF : 1, UT : 1,		CONFIG : 'N U T, 0, 0, 0',
	X =   713.388  mm,	Y =   600.149  mm,	Z =   359.442  mm,
	W =   178.239 deg,	P =     5.647 deg,	R =    68.492 deg
};
P[47]{
   GP1:
	UF : 1, UT : 1,		CONFIG : 'N U T, 0, 0, 0',
	X =  -127.398  mm,	Y =  -563.087  mm,	Z =   548.396  mm,
	W =  -174.010 deg,	P =     5.165 deg,	R =    97.685 deg
};
P[49]{
   GP1:
	UF : 1, UT : 1,		CONFIG : 'N U T, 0, 0, -1',
	X =  -481.135  mm,	Y =  -887.369  mm,	Z =   178.936  mm,
	W =  -178.326 deg,	P =    -2.211 deg,	R =     1.171 deg
};
P[56]{
   GP1:
	UF : 1, UT : 1,		CONFIG : 'N U T, 0, 0, -1',
	X =  -648.689  mm,	Y =  -502.707  mm,	Z =   172.752  mm,
	W =  -178.326 deg,	P =    -2.211 deg,	R =   -22.693 deg
};
/END
