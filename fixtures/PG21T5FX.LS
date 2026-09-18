/PROG  PG21T5FX
/ATTR
OWNER		= MNEDITOR;
COMMENT		= "PG21T 5 BAY CMT";
PROG_SIZE	= 12956;
CREATE		= DATE 25-08-24  TIME 21:14:08;
MODIFIED	= DATE 26-09-18  TIME 00:48:00;
FILE_NAME	= PG21T5FX;
VERSION		= 0;
LINE_COUNT	= 599;
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
   2:  ! MH PG21T MAIN TRANSFER SEQ ;
   3:  ! Pick1 5 bays, Drop2 4 bays ;
   4:  !***************************** ;
   5:  !GO10 = Active program number ;
   6:  GO[10]=21 ;
   7:   ;
   8:  !Startup part recovery check ;
   9:  !DI67 PartPresent + DI74 GrpClosed ;
  10:  IF DI[67]=ON AND DI[74]=ON,JMP LBL[10] ;
  11:   ;
  12:  !Empty gripper payload ;
  13:  !PAYLOAD1 = Robot without part ;
  14:  PAYLOAD[1] ;
  15:   ;
  16:  !Initial transfer permissives ;
  17:  !HOME_IO handled outside this PG ;
  18:   ;
  19:  !Move robot to HOME ;
  20:  GO TO HOME POS    ;
  21:   ;
  22:  !Move robot to POUNCE ;
  23:  GO TO POUNCE    ;
  24:   ;
  25:  !DO954 = Clear to Advance Xfer ;
  26:  DO[954]=ON ;
  27:   ;
  28:  !DO955 = Clear to Return Xfer ;
  29:  DO[955]=ON ;
  30:   ;
  31:  !DO956 = Clear to Unclamp ;
  32:  DO[956]=OFF ;
  33:   ;
  34:  !-------------------------------- ;
  35:  LBL[33:Loop Back] ;
  36:   ;
  37:  !DO24 = Robot In Loop ON ;
  38:  DO[24]=ON ;
  39:   ;
  40:  !-------------------------------- ;
  41:  !Wait for operator or PLC request ;
  42:  !DI9 Continue, DI13 Return Home ;
  43:  WAIT DI[9]=ON OR DI[13]=ON    ;
  44:   ;
  45:  !DO24 = Robot In Loop OFF ;
  46:  DO[24]=OFF ;
  47:  !DI13 ON = Return Home request ;
  48:  !Return Home jumps to LBL13 ;
  49:  IF DI[13]=ON,JMP LBL[13] ;
  50:   ;
  51:  !DI9 ON = Continue from Pounce ;
  52:  !DI1512 = Extra continue permissive ;
  53:  IF DI[9]=ON AND DI[1512]=ON,JMP LBL[9] ;
  54:  !DI1512 exact PLC name not in PG ;
  55:  JMP LBL[33] ;
  56:   ;
  57:  !-------------------------------- ;
  58:  !CONTINUE FROM POUNCE ;
  59:  LBL[9] ;
  60:   ;
  61:  !DO955 Clear to Return Xfer OFF ;
  62:  DO[955]=OFF ;
  63:   ;
  64:  !DO954 Clear to Advance Xfer OFF ;
  65:  DO[954]=OFF ;
  66:   ;
  67:  !DO956 Clear to Unclamp OFF ;
  68:  DO[956]=OFF ;
  69:   ;
  70:  !******************************* ;
  71:  ! PICK SELECTION AND PICKUP ;
  72:  !******************************* ;
  73:   ;
  74:  !DO24 = Robot In Loop ON ;
  75:  DO[24]=ON ;
  76:   ;
  77:  !DI94 = Clear to Pickup ;
  78:  WAIT DI[94]=ON    ;
  79:  !LBL120 chooses Pick1 or Pick2 ;
  80:  LBL[120:Decide Pick 1or2] ;
  81:  J P[23] 100% CNT50    ;
  82:J P[38] 100% FINE    ;
  83:  !DI41 Pick1 request, DI42 Pick2 ;
  84:  WAIT DI[41]=ON OR DI[42]=ON    ;
  85:  IF DI[42]=ON,JMP LBL[109] ;
  86:  IF DI[41]=ON,JMP LBL[110] ;
  87:   ;
  88:  LBL[109:GOTO PICK2] ;
  89:  !******************************* ;
  90:  ! PICK 2 PATH ;
  91:  !******************************* ;
  92:   ;
  93:  !DO24 = Robot In Loop OFF ;
  94:  DO[24]=OFF ;
  95:   ;
  96:  !Reserve shared Zone 1 ;
  97:  ENTER ZONE(1) ;
  98:   ;
  99:  !DI73 = Clamps Open feedback ;
 100:  WAIT DI[73]=ON    ;
 101:  !Move into Pick2 position ;
 102:   ;
 103:J P[1] 100% FINE    ;
 104:   ;
 105:  L P[6] 750mm/sec FINE    ;
 106:  !At Pick2, close gripper ;
 107:  CALL CLP1_CLS    ;
 108:  DO[50]=ON ;
 109:  PAYLOAD[2] ;
 110:  WAIT DI[67]=ON    ;
 111:  !DI67 = Part Present in gripper ;
 112:   ;
 113:  !Reserved Pick2 motion points ;
 114:   ;
 115:   ;
 116:   ;
 117:   ;
 118:   ;
 119:   ;
 120:   ;
 121:   ;
 122:   ;
 123:   ;
 124:   ;
 125:   ;
 126:   ;
 127:  !DO50 request, DI50 acknowledge ;
 128:  DO[50]=ON ;
 129:  WAIT DI[50]=ON    ;
 130:  DO[50]=OFF ;
 131:   ;
 132:  !Move out of Pick2 zone ;
 133:   ;
 134:J P[25] 100% CNT100    ;
 135:J P[7] 100% CNT100    ;
 136:J P[9] 100% FINE    ;
 137:   ;
 138:  !Release shared Zone 1 ;
 139:  EXIT ZONE(1) ;
 140:   ;
 141:  JMP LBL[114] ;
 142:   ;
 143:  LBL[114:MOVE TO DROP 2] ;
 144:   ;
 145:  !MOVE TO DROP 2, RH PART ;
 146:  !Reserve shared Zone 2 ;
 147:  ENTER ZONE(2) ;
 148:   ;
 149:  !Reserve shared Zone 6 ;
 150:  ENTER ZONE(6) ;
 151:   ;
 152:J P[12] 100% FINE    ;
 153:   ;
 154:  LBL[111:GOTO DROP2] ;
 155:  !******************************* ;
 156:  ! DROP 2 PATH, RH PART ;
 157:  !******************************* ;
 158:   ;
 159:  !DO24 = Robot In Loop OFF ;
 160:  DO[24]=OFF ;
 161:   ;
 162:  !Reserve shared Zone 1 ;
 163:  ENTER ZONE(1) ;
 164:   ;
 165:  !DI73 = Clamps Open feedback ;
 166:  WAIT DI[73]=ON    ;
 167:  !Move to Drop2 bay approach ;
 168:   ;
 169:J P[1] 100% FINE    ;
 170:   ;
 171:  !Select Drop2 bay using DI43-DI46 ;
 172:  LBL[140:RHTrlyBay1-4] ;
 173:  !DO43-DO46 = Bay confirm outputs ;
 174:  DO[43]=OFF ;
 175:  DO[44]=OFF ;
 176:  DO[45]=OFF ;
 177:  DO[46]=OFF ;
 178:  WAIT DI[43]=ON OR DI[44]=ON OR DI[45]=ON OR DI[46]=ON    ;
 179:  IF DI[43]=ON,JMP LBL[141] ;
 180:  IF DI[44]=ON,JMP LBL[142] ;
 181:  IF DI[45]=ON,JMP LBL[143] ;
 182:  IF DI[46]=ON,JMP LBL[144] ;
 183:   ;
 184:  !DROP2 Bay1 selected by DI43 ;
 185:  LBL[141:RHPrtTrly-Bay1] ;
 186:J P[2] 100% FINE    ;
 187:   ;
 188:  !DO43 pulse confirms Bay1 ;
 189:  DO[43]=ON ;
 190:  WAIT   1.00(sec) ;
 191:  DO[43]=OFF ;
 192:  !DI43 must stay ON to continue ;
 193:  !If OFF, return to bay selection ;
 194:  IF DI[43]=OFF,JMP LBL[140] ;
 195:  DO[43]=OFF ;
 196:   ;
 197:  !Bay1 vision, DI93 ON = abort ;
 198:  J P[10] 100% FINE    ;
 199:  CALL VIS_RHPART_BAY1    ;
 200:  IF DI[93]=ON,JMP LBL[11] ;
 201:  JMP LBL[121] ;
 202:   ;
 203:  !DROP2 Bay2 selected by DI44 ;
 204:  LBL[142:RHPrtTrly-Bay2] ;
 205:  J P[3] 100% FINE    ;
 206:   ;
 207:  !DO44 pulse confirms Bay2 ;
 208:  DO[44]=ON ;
 209:  WAIT   1.00(sec) ;
 210:  DO[44]=OFF ;
 211:  !DI44 must stay ON to continue ;
 212:  !If OFF, return to bay selection ;
 213:  IF DI[44]=OFF,JMP LBL[140] ;
 214:  DO[44]=OFF ;
 215:   ;
 216:  !Bay2 vision, DI93 ON = abort ;
 217:  J P[8] 100% FINE    ;
 218:  CALL VIS_RHPART_BAY2    ;
 219:  IF DI[93]=ON,JMP LBL[11] ;
 220:  JMP LBL[121] ;
 221:   ;
 222:  !DROP2 Bay3 selected by DI45 ;
 223:  LBL[143:RHPrtTrly-Bay3] ;
 224:  J P[4] 100% FINE    ;
 225:   ;
 226:  !DO45 pulse confirms Bay3 ;
 227:  DO[45]=ON ;
 228:  WAIT   2.00(sec) ;
 229:  DO[45]=OFF ;
 230:  !DI45 must stay ON to continue ;
 231:  !If OFF, return to bay selection ;
 232:  IF DI[45]=OFF,JMP LBL[140] ;
 233:  DO[45]=OFF ;
 234:   ;
 235:  !Bay3 vision, DI93 ON = abort ;
 236:  CALL VIS_RHPART_BAY3    ;
 237:  IF DI[93]=ON,JMP LBL[11] ;
 238:  JMP LBL[121] ;
 239:   ;
 240:  !DROP2 Bay4 selected by DI46 ;
 241:  LBL[144:RHPrtTrly-Bay4] ;
 242:  J P[5] 100% FINE    ;
 243:   ;
 244:  !DO46 pulse confirms Bay4 ;
 245:  DO[46]=ON ;
 246:  WAIT   1.00(sec) ;
 247:  DO[46]=OFF ;
 248:  !DI46 must stay ON to continue ;
 249:  !If OFF, return to bay selection ;
 250:  IF DI[46]=OFF,JMP LBL[140] ;
 251:  DO[46]=OFF ;
 252:   ;
 253:  !Bay4 vision, DI93 ON = abort ;
 254:  CALL VIS_RHPART_BAY4    ;
 255:  IF DI[93]=ON,JMP LBL[11] ;
 256:  JMP LBL[121] ;
 257:   ;
 258:  LBL[121:DROP RH PART] ;
 259:  //L P[6] 750mm/sec FINE    ;
 260:  !At Drop2, DO60 = Drop2 handshake ;
 261:  DO[60]=ON ;
 262:  PAYLOAD[2] ;
 263:  WAIT DI[67]=ON    ;
 264:  !DI67 confirms part still held ;
 265:   ;
 266:  !PR10 temp position, retract Z+30 ;
 267:  PR[10]=LPOS    ;
 268:  PR[10,3]=PR[10,3]+30    ;
 269:L PR[10] 750mm/sec FINE    ;
 270:   ;
 271:   ;
 272:   ;
 273:   ;
 274:  !DO50 request, DI50 acknowledge ;
 275:  DO[50]=ON ;
 276:  WAIT DI[50]=ON    ;
 277:  DO[50]=OFF ;
 278:   ;
 279:  !Move out of Drop2 Zone1 ;
 280:   ;
 281:J P[25] 100% CNT100    ;
 282:J P[7] 100% CNT100    ;
 283:J P[9] 100% FINE    ;
 284:   ;
 285:  !Release shared Zone 1 ;
 286:  EXIT ZONE(1) ;
 287:   ;
 288:  JMP LBL[112] ;
 289:   ;
 290:  LBL[112:Exit Drop 2] ;
 291:  !DO47/DI47 clamp repo handshake ;
 292:  DO[47]=ON ;
 293:  WAIT DI[47]=ON    ;
 294:  DO[47]=OFF ;
 295:  WAIT DI[60]=ON    ;
 296:  !DI60 = Drop2 acknowledge feedback ;
 297:  !Move to Drop2 release point ;
 298:   ;
 299:L P[36] 750mm/sec FINE    ;
 300:   ;
 301:  !DI97 = Part Released feedback ;
 302:  WAIT DI[97]=ON    ;
 303:  PAYLOAD[1] ;
 304:  DO[59]=OFF ;
 305:  DO[60]=OFF ;
 306:  !Reset Drop1 and Drop2 outputs ;
 307:J P[27] 100% CNT20    ;
 308:   ;
 309:  !Release shared Zone 2 ;
 310:  EXIT ZONE(2) ;
 311:  !Release shared Zone 6 ;
 312:  EXIT ZONE(6) ;
 313:   ;
 314:J P[24] 100% FINE    ;
 315:   ;
 316:  !Drop2 complete, return HOME ;
 317:  JMP LBL[13] ;
 318:   ;
 319:  LBL[110:Goto Pick1 RH Pt] ;
 320:  !******************************* ;
 321:  ! PICK 1 PATH, RH PART ;
 322:  !******************************* ;
 323:   ;
 324:  !DO24 = Robot In Loop OFF ;
 325:  DO[24]=OFF ;
 326:   ;
 327:  !Reserve Zone 4 for Pick1 trolley ;
 328:  ENTER ZONE(4) ;
 329:   ;
 330:  !DI73 = Clamps Open feedback ;
 331:  WAIT DI[73]=ON    ;
 332:   ;
 333:  !Move to Pick1 trolley approach ;
 334:J P[16] 100% FINE    ;
 335:   ;
 336:  !Select Pick1 bay using DI43-DI47 ;
 337:  LBL[150:LargeTrlyBay1-5] ;
 338:  DO[43]=OFF ;
 339:  DO[44]=OFF ;
 340:  DO[45]=OFF ;
 341:  DO[46]=OFF ;
 342:  DO[47]=OFF ;
 343:  !DO43-DO47 = Bay confirm outputs ;
 344:  !DI43-DI47 = Bay request inputs ;
 345:  WAIT DI[43]=ON OR DI[44]=ON OR DI[45]=ON OR DI[46]=ON OR DI[47]=ON    ;
 346:  IF DI[43]=ON,JMP LBL[151] ;
 347:  IF DI[44]=ON,JMP LBL[152] ;
 348:  IF DI[45]=ON,JMP LBL[153] ;
 349:  IF DI[46]=ON,JMP LBL[154] ;
 350:  IF DI[47]=ON,JMP LBL[155] ;
 351:   ;
 352:  !PICK1 Bay1 selected by DI43 ;
 353:  LBL[151:RHPrtTrly-Bay1] ;
 354:  !Move to Bay1 approach point ;
 355:J P[22] 100% FINE    ;
 356:  !DO43 pulse confirms Bay1 ;
 357:  DO[43]=ON ;
 358:  WAIT   1.00(sec) ;
 359:  DO[43]=OFF ;
 360:  !DI43 must stay ON to continue ;
 361:  !If OFF, return to bay selection ;
 362:  IF DI[43]=OFF,JMP LBL[150] ;
 363:  DO[43]=OFF ;
 364:   ;
 365:  !Bay1 vision, DI93 ON = abort ;
 366:  CALL VIS_RHPART_BAY1    ;
 367:  IF DI[93]=ON,JMP LBL[12] ;
 368:  JMP LBL[122] ;
 369:   ;
 370:  !PICK1 Bay2 selected by DI44 ;
 371:  LBL[152:RHPrtTrly-Bay2] ;
 372:   ;
 373:J P[19] 100% FINE    ;
 374:   ;
 375:  !DO44 pulse confirms Bay2 ;
 376:  DO[44]=ON ;
 377:  WAIT   1.00(sec) ;
 378:  DO[44]=OFF ;
 379:  !DI44 must stay ON to continue ;
 380:  !If OFF, return to bay selection ;
 381:  IF DI[44]=OFF,JMP LBL[150] ;
 382:  DO[44]=OFF ;
 383:   ;
 384:  !Bay2 vision, DI93 ON = abort ;
 385:  CALL VIS_RHPART_BAY2    ;
 386:  IF DI[93]=ON,JMP LBL[12] ;
 387:  JMP LBL[122] ;
 388:   ;
 389:  !PICK1 Bay3 selected by DI45 ;
 390:  LBL[153:RHPrtTrly-Bay3] ;
 391:   ;
 392:J P[28] 100% FINE    ;
 393:   ;
 394:  !DO45 pulse confirms Bay3 ;
 395:  DO[45]=ON ;
 396:  WAIT   2.00(sec) ;
 397:  DO[45]=OFF ;
 398:  !DI45 must stay ON to continue ;
 399:  !DI294 must also be ON for Bay3 ;
 400:  IF DI[45]=OFF,JMP LBL[150] ;
 401:  DO[45]=OFF ;
 402:  IF DI[294]=OFF,JMP LBL[150] ;
 403:  !DI294 exact PLC name not in PG ;
 404:  !Bay3 vision, DI93 ON = abort ;
 405:  CALL VIS_RHPART_BAY3    ;
 406:  IF DI[93]=ON,JMP LBL[12] ;
 407:  JMP LBL[122] ;
 408:   ;
 409:  !PICK1 Bay4 selected by DI46 ;
 410:  LBL[154:RHPrtTrly-Bay4] ;
 411:   ;
 412:J P[39] 100% FINE    ;
 413:   ;
 414:  !DO46 pulse confirms Bay4 ;
 415:  DO[46]=ON ;
 416:  WAIT   1.00(sec) ;
 417:  DO[46]=OFF ;
 418:  !DI46 must stay ON to continue ;
 419:  !If OFF, return to bay selection ;
 420:  IF DI[46]=OFF,JMP LBL[150] ;
 421:  DO[46]=OFF ;
 422:   ;
 423:  !Bay4 vision, DI93 ON = abort ;
 424:  CALL VIS_RHPART_BAY4    ;
 425:  IF DI[93]=ON,JMP LBL[12] ;
 426:  JMP LBL[122] ;
 427:   ;
 428:  !PICK1 Bay5 selected by DI47 ;
 429:  LBL[155:RHPrtTrly-Bay5] ;
 430:   ;
 431:  !RETEACH P57 FOR BAY5 BEFORE AUTO ;
 432:J P[57] 100% FINE    ;
 433:   ;
 434:  !DO47 pulse confirms Bay5 ;
 435:  DO[47]=ON ;
 436:  WAIT   1.00(sec) ;
 437:  DO[47]=OFF ;
 438:  !DI47 must stay ON to continue ;
 439:  !If OFF, return to bay selection ;
 440:  IF DI[47]=OFF,JMP LBL[150] ;
 441:  DO[47]=OFF ;
 442:   ;
 443:  !Bay5 vision, DI93 ON = abort ;
 444:  CALL VIS_RHPART_BAY5    ;
 445:  IF DI[93]=ON,JMP LBL[12] ;
 446:  JMP LBL[122] ;
 447:   ;
 448:  LBL[122:PICK RH PART] ;
 449:  L P[17] 100mm/sec FINE    ;
 450:  !At Pick1 position, start handshake ;
 451:  DO[50]=ON ;
 452:  PAYLOAD[3] ;
 453:  WAIT DI[67]=ON    ;
 454:  !DI67 = Part Present in gripper ;
 455:  !PR10 = Temporary Pick1 exit pos ;
 456:  PR[10]=LPOS    ;
 457:  PR[10,1]=PR[10,1]-3    ;
 458:  PR[10,3]=PR[10,3]+10    ;
 459:  PR[10,4]=(-179.899)    ;
 460:  PR[10,5]=(-6)    ;
 461:L PR[10] 750mm/sec FINE    ;
 462:  PR[10,2]=PR[10,2]+8    ;
 463:  PR[10,3]=PR[10,3]+R[1]-78    ;
 464:L PR[10] 750mm/sec FINE    ;
 465:  !R1 = Pick1 Z process offset ;
 466:  DO[49]=ON ;
 467:  WAIT DI[49]=ON    ;
 468:  DO[49]=OFF ;
 469:  !DO49 request, DI49 acknowledge ;
 470:  !Release Pick1 Zone 4 ;
 471:  EXIT ZONE(4) ;
 472:  JMP LBL[115] ;
 473:   ;
 474:  LBL[115:GOTO DROP 1] ;
 475:   ;
 476:J P[11] 100% FINE    ;
 477:J P[14] 100% FINE    ;
 478:   ;
 479:  !MOVE TO DROP 1, RH PART ;
 480:  !Reserve shared Zone 2 ;
 481:  ENTER ZONE(2) ;
 482:   ;
 483:  !Reserve shared Zone 6 ;
 484:  ENTER ZONE(6) ;
 485:   ;
 486:J P[30] 100% FINE    ;
 487:L P[37] 750mm/sec CNT100    ;
 488:L P[33] 750mm/sec CNT50    ;
 489:L P[34] 750mm/sec FINE    ;
 490:  !Keep PAYLOAD3 until part release ;
 491:L P[35] 750mm/sec FINE    ;
 492:  !At Drop1, DO59 = Drop1 handshake ;
 493:  DO[59]=ON ;
 494:  CALL CLP1_OPN    ;
 495:  JMP LBL[113] ;
 496:   ;
 497:  LBL[113:Exit Drop 1] ;
 498:  !DO47/DI47 clamp repo handshake ;
 499:  DO[47]=ON ;
 500:  WAIT DI[47]=ON    ;
 501:  DO[47]=OFF ;
 502:  WAIT DI[59]=ON    ;
 503:  !DI59 = Drop1 acknowledge feedback ;
 504:  !Move through Drop1 release path ;
 505:   ;
 506:L P[42] 750mm/sec FINE    ;
 507:   ;
 508:  !DI97 = Part Released feedback ;
 509:  WAIT DI[97]=ON    ;
 510:  PAYLOAD[1] ;
 511:  DO[59]=OFF ;
 512:  DO[60]=OFF ;
 513:  !Reset Drop1 and Drop2 outputs ;
 514:J P[43] 100% CNT100    ;
 515:J P[21] 100% CNT10    ;
 516:   ;
 517:  !Release shared Zone 2 ;
 518:  EXIT ZONE(2) ;
 519:  !Release shared Zone 6 ;
 520:  EXIT ZONE(6) ;
 521:   ;
 522:J P[47] 100% CNT20    ;
 523:  !Drop1 complete, continue to Pick2 ;
 524:  JMP LBL[109] ;
 525:   ;
 526:  LBL[11:Abort DROP2] ;
 527:  !ABORT DROP2 recovery ;
 528:  !DI66 No Parts, DI73 Clamps Open ;
 529:  WAIT DI[66]=ON    ;
 530:  WAIT DI[73]=ON    ;
 531:  PR[10]=LPOS    ;
 532:  !Recovery uses absolute UF Z=100 ;
 533:  PR[10,3]=100    ;
 534:L PR[10] 750mm/sec FINE    ;
 535:   ;
 536:J P[49] 100% FINE    ;
 537:J P[56] 100% CNT100    ;
 538:   ;
 539:  !Release all Drop2 reserved zones ;
 540:  EXIT ZONE(1) ;
 541:  EXIT ZONE(2) ;
 542:  EXIT ZONE(6) ;
 543:   ;
 544:  JMP LBL[13] ;
 545:   ;
 546:  LBL[12:Abort Pick] ;
 547:  !ABORT PICK1 recovery ;
 548:  !DI66 No Parts, DI73 Clamps Open ;
 549:  WAIT DI[66]=ON    ;
 550:  WAIT DI[73]=ON    ;
 551:  PR[10]=LPOS    ;
 552:  !Recovery uses absolute UF Z=100 ;
 553:  PR[10,3]=100    ;
 554:L PR[10] 750mm/sec FINE    ;
 555:   ;
 556:J P[18] 100% FINE    ;
 557:J P[20] 100% CNT100    ;
 558:   ;
 559:  !Release Pick1 Zone 4 ;
 560:  EXIT ZONE(4) ;
 561:   ;
 562:  JMP LBL[13] ;
 563:   ;
 564:  !-------------------------------- ;
 565:  LBL[10:Skip Pickup ] ;
 566:   ;
 567:  !PART ALREADY HELD, SKIP PICKUP ;
 568:  !DO955 Clear to Return Xfer OFF ;
 569:  DO[955]=OFF ;
 570:   ;
 571:  !DO954 Clear to Advance Xfer OFF ;
 572:  DO[954]=OFF ;
 573:   ;
 574:  !DO956 Clear to Unclamp OFF ;
 575:  DO[956]=OFF ;
 576:   ;
 577:  !Part held, keep current payload ;
 578:  !Do not force empty PAYLOAD1 here ;
 579:   ;
 580:  !-------------------------------- ;
 581:  !DI354 = Skip Rivet request ;
 582:  !NOTE: both DI354 states reach LBL222 ;
 583:  IF DI[354]=ON,JMP LBL[222] ;
 584:   ;
 585:  !No alternate rivet path in this PG ;
 586:  !LBL222 sends robot directly HOME ;
 587:   ;
 588:  !SKIP RIVET TARGET ;
 589:  LBL[222:Skip Rivet] ;
 590:  JMP LBL[13] ;
 591:   ;
 592:  LBL[13:Return to Home ] ;
 593:  !-------------------------------- ;
 594:  !Move robot to HOME ;
 595:  GO TO HOME POS    ;
 596:   ;
 597:  !Reset GO10 program feedback ;
 598:  GO[10]=0 ;
 599:   ;
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
P[57]{
   GP1:
	UF : 1, UT : 1,		CONFIG : 'N U T, 0, 0, -1',
	X =  -648.689  mm,	Y =  -502.707  mm,	Z =   172.752  mm,
	W =  -178.326 deg,	P =    -2.211 deg,	R =   -22.693 deg
};
/END
