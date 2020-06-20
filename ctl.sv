// Schematic review 2020-06-19: CTL1, CTL2, CTL3
`timescale 1ns/1ps
`include "ebox.svh"

// M8543 CTL
module ctl(iAPR APR,
           iCLK CLK,
           iCON CON,
           iCTL CTL,
           iCRAM CRAM,
           iEDP EDP,
           iMBOX MBOX,
           iMCL MCL,
           iPI PIC,
           iSHM SHM,

           iEBUS.mod EBUS
);

  bit CTL_36_BIT_EA;
  bit RESET;
  bit [0:8] REG_CTL;
  bit DISP_AREAD, DISP_RET, DISP_MUL, DISP_DIV, DISP_NORM, DISP_EA_MOD;
  bit MQ_CLR;
  bit ARL_SEL_4, ARL_SEL_2, ARL_SEL_1, ARR_SEL_2, ARR_SEL_1;
  bit ARXL_SEL_2, ARXL_SEL_1, ARXR_SEL_2, ARXR_SEL_1;

  // This big-endian bit numbering is SUCH A PAIN IN THE ASS. I tried
  // manually converting power-of-2 naming convention to bit index
  // directly and made so many mistakes I decided to do this in one
  // place carefully and accurately and stay true to the schematic
  // naming (sorta) elsewhere.
  assign CTL.ARL_SEL = {ARL_SEL_4, ARL_SEL_2, ARL_SEL_1};
  assign CTL.ARR_SEL = {ARR_SEL_2, ARR_SEL_1};
  assign CTL.ARXL_SEL = {ARXL_SEL_2, ARXL_SEL_1};
  assign CTL.ARXR_SEL = {ARXR_SEL_2, ARXR_SEL_1};

  // p.364: Decode all the things.
  // Dispatches
  assign DISP_AREAD = CRAM.DISP == dispDRAM_A_RD;
  assign CTL.DISP_RETURN = CRAM.DISP == dispRETURN;
  assign CTL.DISP_NICOND = CRAM.DISP == dispNICOND;
  assign DISP_MUL = CRAM.DISP == dispMUL;
  assign DISP_DIV = CRAM.DISP == dispDIV;
  assign DISP_NORM = CRAM.DISP == dispNORM;
  assign DISP_EA_MOD = CRAM.DISP == dispEA_MOD;
  
  // Special functions
  bit SPEC_INH_CRY_18, SPEC_MQ_SHIFT, SPEC_LOAD_PC, SPEC_XCRY_AR0;
  bit SPEC_STACK_UPDATE, SPEC_ARL_IND;
  bit SPEC_MTR_CTL, SPEC_SBR_CALL;

  assign SPEC_INH_CRY_18 = CRAM.SPEC == specINH_CRY18;
  assign SPEC_MQ_SHIFT = CRAM.SPEC == specMQ_SHIFT;
  assign CTL.SPEC_SCM_ALT = CRAM.SPEC == specSCM_ALT;
  assign CTL.SPEC_CLR_FPD = CRAM.SPEC == specCLR_FPD;
  assign SPEC_LOAD_PC = CRAM.SPEC == specLOAD_PC;
  assign SPEC_XCRY_AR0 = CRAM.SPEC == specXCRY_AR0;
  assign CTL.SPEC_GEN_CRY_18 = CRAM.SPEC == specGEN_CRY18;
  assign SPEC_STACK_UPDATE = CRAM.SPEC == specSTACK_UPDATE;
  assign SPEC_SBR_CALL = CRAM.SPEC == specSUBR_CALL;
  assign SPEC_ARL_IND = CRAM.SPEC == specARL_IND;
  assign CTL.SPEC_FLAG_CTL = CRAM.SPEC == specFLAG_CTL;
  assign CTL.SPEC_SAVE_FLAGS = CRAM.SPEC == specSAVE_FLAGS;
  assign CTL.SPEC_SP_MEM_CYCLE = CRAM.SPEC == specSP_MEM_CYCLE;
  assign CTL.SPEC_AD_LONG = CRAM.SPEC == specAD_LONG;

  // This one is internal because of reclock with APR_CLK below.
  assign SPEC_MTR_CTL = CRAM.SPEC == specMTR_CTL;

  // EBUS
  assign CTL.EBUSdriver.driving = CTL.DIAG_READ;

  always_comb unique case (CTL.DIAG[4:6])
              default: CTL.EBUSdriver.data[24:28] = 0;
              3'b000: CTL.EBUSdriver.data[24:28] = {CTL.SPEC_SCM_ALT,
                                                    CTL.SPEC_SAVE_FLAGS,
                                                    ARL_SEL_2,
                                                    ~CTL.ARR_LOAD,
                                                    ~CTL.AR00to08_LOAD};
              3'b001: CTL.EBUSdriver.data[24:28] = {CTL.SPEC_CLR_FPD,
                                                    ~CTL.SPEC_MTR_CTL,
                                                    ARL_SEL_1,
                                                    ~CTL.ARR_LOAD,
                                                    ~CTL.AR09to17_LOAD};
              3'b010: CTL.EBUSdriver.data[24:28] = {CTL.SPEC_GEN_CRY_18,
                                                    CTL.COND_AR_EXP,
                                                    ARR_SEL_2,
                                                    CTL.MQM_SEL[0],
                                                    CTL.ARX_LOAD};
              3'b011: CTL.EBUSdriver.data[24:28] = {SPEC_STACK_UPDATE,
                                                    ~DISP_RET,
                                                    ARR_SEL_1,
                                                    CTL.MQM_SEL[1],
                                                    ARL_SEL_4};
              3'b100: CTL.EBUSdriver.data[24:28] = {CTL.SPEC_FLAG_CTL,
                                                    ~CTL.LOAD_PC,
                                                    ARXL_SEL_2,
                                                    CTL.MQ_SEL[0],
                                                    CTL.AR00to11_CLR};
              3'b101: CTL.EBUSdriver.data[24:28] = {CTL.SPEC_SP_MEM_CYCLE,
                                                    CTL.ADX_CRY_36,
                                                    ARXL_SEL_1,
                                                    CTL.MQ_SEL[1],
                                                    CTL.AR12to17_CLR};
              3'b110: CTL.EBUSdriver.data[24:28] = {CTL.AD_LONG,
                                                    CTL.ADX_CRY_36,
                                                    ARXR_SEL_2,
                                                    CTL.MQM_EN,
                                                    CTL.ARR_CLR};
              3'b111: CTL.EBUSdriver.data[24:28] = {CTL.INH_CRY_18,
                                                    MBOX.DIAG_MEM_RESET,
                                                    ~ARXR_SEL_1,
                                                    ~CTL.DIAG_LD_EBUS_REG,
                                                    ~CTL.SPEC_CALL};
              endcase
  
  // Miscellaneous control signals CTL1
  assign CTL.PI_CYCLE_SAVE_FLAGS = CON.PCplus1_INH & CTL.SPEC_SAVE_FLAGS;

  // This is "CRAM.AD & adCARRY" term is actually shown on CTL1
  // E8 pins 5 and 7 as CRAM AD CRY. I'm just guessing this is
  // what they mean since I don't have backplane wiring.
  bit cram_ad_cry;
  assign cram_ad_cry = (CRAM.AD & `adCARRY) !== 0;
  assign CTL.ADX_CRY_36 = ~CTL.PI_CYCLE_SAVE_FLAGS &
                          cram_ad_cry ^ (EDP.AR[0] & SPEC_XCRY_AR0);

  assign REG_CTL[0:2]    = CRAM.MAGIC[0:2] & {3{COND_REG_CTL}};
  assign CTL.COND_AR_EXP = CRAM.MAGIC[5]   & COND_REG_CTL;
  assign REG_CTL[7:8]    = CRAM.MAGIC[7:8] & {2{COND_REG_CTL}};

  bit e12q15;
  assign e12q15 = (~APR.CLK & e12q15) |
                  (SPEC_LOAD_PC | CTL.DISP_NICOND) & ~CLK.SBR_CALL;
  assign CTL.LOAD_PC = ~CON.PI_CYCLE & e12q15;

  assign CTL.GEN_CRY_18 = (CTL.SPEC_GEN_CRY_18 | SPEC_STACK_UPDATE) &
                          (CTL.SPEC_GEN_CRY_18 | MCL.SHORT_STACK);

  assign CTL.INH_CRY_18 = (SPEC_INH_CRY_18 | CTL.SPEC_SAVE_FLAGS | SPEC_STACK_UPDATE) &
                          (SPEC_INH_CRY_18 | CTL.SPEC_SAVE_FLAGS | ~cram_ad_cry) &
                          (SPEC_INH_CRY_18 | CTL.SPEC_SAVE_FLAGS | MCL.SHORT_STACK);

  assign CTL.DISP_EN = CRAM.DISP[0:1];
  assign RESET = CLK.MR_RESET;
  assign CTL.AD_LONG = DISP_MUL | DISP_DIV | DISP_NORM | CTL.SPEC_AD_LONG | SPEC_MQ_SHIFT;
  assign DISP_RET = ~(~CLK.SBR_CALL | ~CTL.DISP_RETURN);
  assign CTL.SPEC_MTR_CTL = SPEC_MTR_CTL & ~APR.CLK;


  // CTL2 p.365

  bit ARL_IND_SEL_2, ARL_IND_SEL_1;
  bit COND_AR_CLR, COND_ARX_CLR;
  bit COND_ARLL_LOAD, COND_ARLR_LOAD;
  bit COND_ARL_IND;
  bit COND_ARR_LOAD;
  bit COND_REG_CTL;

  bit DIAG_AR_LOAD, ARL_IND;

  assign CTL.ARR_LOAD = REG_CTL[2] | CRAM.AR[0] |
                        ARR_SEL_2 | ARR_SEL_1 |
                        CTL.ARR_CLR | COND_ARR_LOAD;
  bit load1;
  assign load1 = CTL.AR00to11_CLR | |CTL.ARL_SEL;
  assign CTL.AR09to17_LOAD = COND_ARLR_LOAD | REG_CTL[1] | load1;
  assign CTL.AR00to08_LOAD = COND_ARLL_LOAD | REG_CTL[0] | load1 | CRAM.MAGIC[1] & ARL_IND;

  assign MQ_CLR = ARL_IND ? CRAM.MAGIC[2] : 0;
  assign CTL.ARX_CLR = ARL_IND ? CRAM.MAGIC[3] : COND_ARX_CLR;
  assign CTL.AR00to11_CLR = CTL.AR12to17_CLR | MCL._23_BIT_EA;
  assign CTL.AR12to17_CLR = RESET | MCL._18_BIT_EA |
                            (ARL_IND ? CRAM.MAGIC[4] : COND_AR_CLR) |
                            DISP_EA_MOD & EDP.ARX[18];
  assign CTL.ARR_CLR = ARL_IND ? CRAM.MAGIC[5] : COND_AR_CLR;

  assign CTL.SPEC_CALL = CLK.SBR_CALL | (ARL_IND ? CRAM.MAGIC[0] : SPEC_SBR_CALL);
  assign ARL_SEL_4 = ARL_IND ? CRAM.MAGIC[6] : CRAM.AR[0];
  assign ARL_IND_SEL_2 = ARL_IND ? CRAM.MAGIC[7] : CRAM.AR[1];
  assign ARL_IND_SEL_1 = ARL_IND ? CRAM.MAGIC[8] : CRAM.AR[2];

  bit FMandAR_LOAD;
  assign FMandAR_LOAD = CON.FM_XFER & MCL.LOAD_AR;
  assign ARL_SEL_2 = ARL_IND_SEL_2 | CTL_36_BIT_EA |
                     DIAG_AR_LOAD | FMandAR_LOAD |
                     DISP_EA_MOD;
  assign ARR_SEL_2 = CRAM.AR[1] | DISP_AREAD | DIAG_AR_LOAD | FMandAR_LOAD;

  assign ARL_SEL_1 = (MCL.LOAD_AR | ARL_IND_SEL_1 | DIAG_AR_LOAD |
                      CLK.RESP_MBOX | CLK.RESP_SIM) &
                     (ARL_IND_SEL_1 | DIAG_AR_LOAD | CLK.RESP_MBOX | CLK.RESP_SIM);

  bit FMandARX_LOAD;
  assign FMandARX_LOAD = CON.FM_XFER & MCL.LOAD_ARX;
  assign ARXL_SEL_2 = CRAM.ARX[1] | FMandARX_LOAD;
  assign ARXR_SEL_2 = CRAM.ARX[1] | FMandARX_LOAD;

  assign CTL.ARX_LOAD = CRAM.ARX[0] | ARXR_SEL_2 | ARXR_SEL_1 | CTL.ARX_CLR | RESET;

  assign ARL_IND = MCL.MEM_ARL_IND | SPEC_ARL_IND | COND_ARL_IND;

  assign CTL.EBUS_XFER = ~CRAM.AR[0] & ~APR.CONO_OR_DATAO & CRAM.AR[1] & CRAM.AR[2];
  assign CTL_36_BIT_EA = DISP_AREAD & ~CTL.AR00to11_CLR;

  assign COND_ARLL_LOAD = CON.COND_EN_00_07 & (CRAM.COND[3:5] == 3'b001);
  assign COND_ARLR_LOAD = CON.COND_EN_00_07 & (CRAM.COND[3:5] == 3'b010);
  assign COND_ARR_LOAD =  CON.COND_EN_00_07 & (CRAM.COND[3:5] == 3'b011);
  assign COND_AR_CLR =    CON.COND_EN_00_07 & (CRAM.COND[3:5] == 3'b100);
  assign COND_ARX_CLR =   CON.COND_EN_00_07 & (CRAM.COND[3:5] == 3'b101);
  assign COND_ARL_IND =   CON.COND_EN_00_07 & (CRAM.COND[3:5] == 3'b110);
  assign COND_REG_CTL =   CON.COND_EN_00_07 & (CRAM.COND[3:5] == 3'b111);

  assign ARXL_SEL_1 = (MCL.LOAD_ARX | CRAM.ARX[2]) &
                      (CRAM.ARX[2] | CLK.RESP_MBOX | CLK.RESP_SIM);
  assign ARXR_SEL_1 = ARXL_SEL_1;

  bit resetOrREG_CTLorMQ_CLR;
  assign resetOrREG_CTLorMQ_CLR = RESET | REG_CTL[7] | MQ_CLR;
  bit mathOrREG_CTLorMQ_CLR;
  assign mathOrREG_CTLorMQ_CLR = MQ_CLR | REG_CTL[8] | SPEC_MQ_SHIFT | DISP_MUL | DISP_DIV;

  assign CTL.MQM_EN = CRAM.MQ | RESET;
  assign CTL.MQM_SEL[0] = CTL.MQM_EN ? resetOrREG_CTLorMQ_CLR : 0;
  assign CTL.MQM_SEL[1] = CTL.MQM_EN ? ~mathOrREG_CTLorMQ_CLR : 0;
  assign CTL.MQ_SEL[0]  = CTL.MQM_EN ? 0 : ~resetOrREG_CTLorMQ_CLR;
  assign CTL.MQ_SEL[1]  = CTL.MQM_EN ? 0 : ~mathOrREG_CTLorMQ_CLR;


  // CTL3 p.366
  bit NOTds00AndDiagStrobe;
  bit en1xx;
  assign CTL.DIAG_READ = EDP.DIAG_READ_FUNC_10x;
  assign CTL.DIAG_STROBE = EBUS.diagStrobe;
  assign NOTds00AndDiagStrobe = ~EBUS.ds[0] & CTL.DIAG_STROBE;

  bit e6X2, e6X3;
  decoder e6(.en(~EBUS.ds[0] & CTL.DIAG_STROBE),
             .sel(EBUS.ds[1:3]),
             .q({CTL.DIAG_CTL_FUNC_00x,
                 CTL.DIAG_CTL_FUNC_01x,
                 e6X2,
                 e6X3,
                 CTL.DIAG_LD_FUNC_04x,
                 CTL.DIAG_LOAD_FUNC_05x,
                 CTL.DIAG_LOAD_FUNC_06x,
                 CTL.DIAG_LOAD_FUNC_07x}));

  decoder e1(.en(CTL.DIAG_LOAD_FUNC_07x),
             .sel(EBUS.ds[4:6]),
             .q({CTL.DIAG_LOAD_FUNC_070,
                 CTL.DIAG_LOAD_FUNC_071,
                 CTL.DIAG_LOAD_FUNC_072,
                 CTL.DIAG_LD_FUNC_073,
                 CTL.DIAG_LD_FUNC_074,
                 CTL.DIAG_SYNC_FUNC_075,
                 CTL.DIAG_LD_FUNC_076,
                 CTL.DIAG_CLK_EDP}));

  decoder e17(.en(EBUS.ds[0] & CTL.READ_STROBE),
              .sel(EBUS.ds[1:3]),
              .q({EDP.DIAG_READ_FUNC_10x,
                  CTL.DIAG_READ_FUNC_11x,
                  CTL.DIAG_READ_FUNC_12x,
                  CTL.DIAG_READ_FUNC_13x,
                  CTL.DIAG_READ_FUNC_14x,
                  CTL.DIAG_READ_FUNC_15x,
                  CTL.DIAG_READ_FUNC_16x,
                  CTL.DIAG_READ_FUNC_17x}));

  // E14 b0
  assign CTL.READ_STROBE = CTL.CONSOLE_CONTROL ?
                           CTL.DIAG_STROBE :
                           CON.COND_DIAG_FUNC & ~APR.CLK;

  assign CTL.CONSOLE_CONTROL = EBUS.ds[0] | EBUS.ds[1];
  assign CTL.DS = CTL.CONSOLE_CONTROL ? EBUS.ds : CRAM.MAGIC[2:8];
  assign CTL.DIAG[4:6] = CTL.DS[4:6];

  assign CTL.AD_TO_EBUS_L = ~CTL.CONSOLE_CONTROL &
                            (APR.CONO_OR_DATAO |
                             CON.COND_DIAG_FUNC & ~CRAM.MAGIC[2] & ~APR.CLK);
  assign CTL.AD_TO_EBUS_R = CTL.AD_TO_EBUS_L;

  assign DIAG_AR_LOAD = ~CTL.DS[0] & &EBUS.ds[1:3] & &CTL.DIAG[4:6];

  assign CTL.EBUS_T_TO_E_EN = (PIC.GATE_TTL_TO_ECL | APR.CONI_OR_DATAI) &
                              ~CTL.CONSOLE_CONTROL |
                              EBUS.ds[0] & CTL.CONSOLE_CONTROL;
  assign CTL.EBUS_E_TO_T_EN = ~APR.EBUS_RETURN & ~CTL.EBUS_T_TO_E_EN |
                              CTL.CONSOLE_CONTROL & ~CTL.EBUS_T_TO_E_EN;
  assign CTL.EBUS_PARITY_OUT = SHM.AR_PAR_ODD | CTL.AD_TO_EBUS_L;

  // E37
  always_ff @(negedge CTL.DIAG_LD_FUNC_076) begin
    MBOX.DIAG_MEM_RESET <= EBUS.data[24];
    CTL.DIAG_CHANNEL_CLK_STOP <= EBUS.data[25];
    CTL.DIAG_LD_EBUS_REG <= EBUS.data[26];
    CTL.DIAG_FORCE_EXTEND <= EBUS.data[27];
//    CTL.DIAG_DIAG[4] <= EBUS.data[28];        // NOT USED ANYWHERE
  end
endmodule
