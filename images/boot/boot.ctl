@COMPILE /COMPILE SYSFLG.MAC+BOOT.MAC BOOT
@LINK
*/NOSYM
*/SET:.LOW.:40000
*BOOT,SYS:DXMCA.RMC/G
@CSAVE BOOT 40000
@R RSXFMT
*CONVERT BOOT.EXE BOOT.EXB
@COMPILE /COMPILE SYSFLG.MAC+PMT.MAC+BOOT MTBOOT
@LINK
*/NOSYM
*/SET:.LOW.:40000
*MTBOOT,SYS:DXMCA.RMC/G
@CSA MTBOOT 40000
@R RSXFMT
@COMPILE /COMPILE SYSFLG.MAC+RP2.MAC+BOOT.MAC RP2DBT
@LINK
*/NOSYM
*/SET:.LOW.:40000
*RP2DBT,SYS:DXMCA.RMC,SYS:DXMCE.RMC/G
@CSAVE RP2DBT 40000
@R RSXFMT
*CONVERT RP2DBT.EXE RP2DBT.EXB
@COMPILE /COMPILE SYSFLG.MAC+PMT.MAC+RP2.MAC+BOOT RP2MBT
@LINK
*/NOSYM
*/SET:.LOW.:40000
*RP2MBT,SYS:DXMCA.RMC,SYS:DXMCE.RMC/G
@CSA RP2MBT 40000 
@R RSXFMT
*CONVERT RP2MBT.EXE RP2MBT.EXB
@
