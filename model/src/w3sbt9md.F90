#include "w3macros.h"
!/ ------------------------------------------------------------------- /
MODULE W3SBT9MD
  !/
  !/                  +-----------------------------------+
  !/                  | WAVEWATCH III           NOAA      |
  !/                  |           M. Orzech     NRL       |
  !/                  |           W. E. Rogers  NRL       |
  !/                  |                        FORTRAN 90 |
  !/                  | Last update :         21-Nov-2013 |
  !/                  +-----------------------------------+
  !/
  !/    28-Jul-2011 : Origination.                        ( version 4.01 )
  !/    21-Nov-2013 : Preparing distribution version.     ( version 4.11 )
  !/
  !/    Copyright 2009 National Weather Service (NWS),
  !/       National Oceanic and Atmospheric Administration.  All rights
  !/       reserved.  WAVEWATCH III is a trademark of the NWS.
  !/       No unauthorized use without permission.
  !/
  !  1. Purpose :
  !
  !     Contains routines for computing dissipation by viscous fluid mud using
  !     Ng (2000)
  !
  !  2. Variables and types :
  !
  !      Name      Type  Scope    Description
  !     ----------------------------------------------------------------
  !     ----------------------------------------------------------------
  !
  !  3. Subroutines and functions :
  !
  !      Name      Type  Scope    Description
  !     ----------------------------------------------------------------
  !      W3SBT9    Subr. Public   Fluid mud dissipation (Ng 2000)
  !     ----------------------------------------------------------------
  !
  !  4. Subroutines and functions used :
  !
  !      Name      Type  Module   Description
  !     ----------------------------------------------------------------
  !      STRACE    Subr. W3SERVMD Subroutine tracing.
  !      CSINH     Subr.   ??     Complex sinh function
  !      CCOSH     Subr.   ??     Complex cosh function
  !      Z_WNUMB   Subr.   ??     Compute wave number from freq & depth
  !     ----------------------------------------------------------------
  !
  !  5. Remarks :
  !     Historical information:
  !        This started as some equations (the "B" parameter equations
  !        in subroutine "Ng" below) in a standalone Fortran
  !        code written by Jim Kaihatu, December 2004. These were adapted by
  !        Erick Rogers for a simple model based on governing equation
  !        similar to SWAN, and installed in a full version of SWAN in
  !        March 2005 with an informal report in May 2005. Kaihatu provided
  !        a "patch" for the B equations May 2006. Mud code in SWAN v40.41A was
  !        finalized June 2006, and v40.51 August 2007. The code was applied
  !        to Cassino Beach ~Sep 2006. This work was presented at a conference
  !        in Brazil Nov 2006, and later published in Rogers and Holland
  !        (CSR 2009). The code was adapted for WW3 by Mark Orzech in Nov 2012
  !        (he had installed the D&L routines as BT8 in July 2011).
  !
  !     Reference: Ng, C.O.,2000. Water waves over a muddy bed:
  !                a two-layer Stokes’ boundary layer model.
  !                Coastal Engineering 40(3),221–242.
  !
  !  6. Switches :
  !
  !     !/S  Enable subroutine tracing.
  !
  !  7. Source code :
  !/
  !/ ------------------------------------------------------------------- /
  !/
  !
  PUBLIC
  !/
CONTAINS
  !/ ------------------------------------------------------------------- /
  SUBROUTINE W3SBT9(AC,H_WDEPTH,S,D,IX,IY)
    !/
    !/                  +-----------------------------------+
    !/                  | WAVEWATCH III           NOAA      |
    !/                  |           M. Orzech     NRL       |
    !/                  |           W. E. Rogers  NRL       |
    !/                  |                        FORTRAN 90 |
    !/                  | Last update :         21-Nov-2013 |
    !/                  +-----------------------------------+

    !/    28-Jul-2011 : Origination.                        ( version 4.01 )
    !/    21-Nov-2013 : Preparing distribution version.     ( version 4.11 )
    !/
    !  1. Purpose :
    !
    !     Compute dissipation by viscous fluid mud using Ng (2000)
    !     (adapted from Erick Rogers code by Mark Orzech, NRL).
    !
    !  2. Method :
    !
    !  3. Parameters :
    !
    !     Parameter list
    !     ----------------------------------------------------------------
    !       H_WDEPTH  Real  I   Mean water depth.
    !       S         R.A.  O   Source term (1-D version).
    !       D         R.A.  O   Diagonal term of derivative (1-D version).
    !     ----------------------------------------------------------------
    !
    !  4. Subroutines used :
    !
    !      Name      Type  Module   Description
    !     ----------------------------------------------------------------
    !      STRACE    Subr. W3SERVMD Subroutine tracing.
    !      CALC_ND
    !      NG
    !     ----------------------------------------------------------------
    !
    !  5. Called by :
    !
    !      Name      Type  Module   Description
    !     ----------------------------------------------------------------
    !      W3SRCE    Subr. W3SRCEMD Source term integration.
    !      W3EXPO    Subr.   N/A    Point output post-processor.
    !      GXEXPO    Subr.   N/A    GrADS point output post-processor.
    !     ----------------------------------------------------------------
    !
    !  6. Error messages :
    !
    !       None.
    !
    !  7. Remarks :
    !
    !     Cg_mud calculation could be improved by using dsigma/dk instead
    !        of n*C. The latter is a "naive" method and its accuracy has
    !        not been confirmed.
    !
    !  8. Structure :
    !
    !     See source code.
    !
    !  9. Switches :
    !
    !     !/S  Enable subroutine tracing.
    !
    ! 10. Source code :
    !
    !/ ------------------------------------------------------------------- /
    USE W3GDATMD, ONLY: NK,SIG,NSPEC,MAPWN
    USE W3IDATMD, ONLY: MUDT, MUDV, MUDD, INFLAGS1
    USE CONSTANTS, ONLY: PI,GRAV,DWAT,NU_WATER
    USE W3SERVMD, ONLY: EXTCDE
    USE W3ODATMD, ONLY: NDSE
#ifdef W3_S
    USE W3SERVMD, ONLY: STRACE
#endif
    !/
    IMPLICIT NONE
    !/
    !/ ------------------------------------------------------------------- /
    !/ Parameter list
    !/
    REAL,    INTENT(IN)  :: H_WDEPTH  ! WATER DEPTH, DENOTED "H" IN NG (M)
    REAL,    INTENT(IN)  :: AC(NSPEC) ! ACTION DENSITY
    INTEGER, INTENT(IN)  :: IX, IY
    REAL,    INTENT(OUT) :: S(NSPEC), D(NSPEC)
    !/
    !/ ------------------------------------------------------------------- /
    !/ Local parameters
    !/
#ifdef W3_S
    INTEGER, SAVE           :: IENT = 0
#endif

    !  LOCAL VARIABLES
    REAL :: DMW(NK)
    REAL :: ROOTDG
    REAL :: SND
    REAL :: SND2
    REAL :: WGD
    REAL :: CWAVE
    REAL :: KD_ROCK
    REAL :: CG_MUD
    REAL :: K_MUD
    REAL :: NWAVE_MUD
    REAL :: ND_MUD
    REAL :: SMUDWD(NK) !  DISSIPATION DUE TO MUD
    REAL :: CG_ROCK
    REAL :: K_ROCK
    REAL :: NWAVE_ROCK
    REAL :: ND_ROCK
    REAL :: KINVISM       ! := THE KINEMATIC VISCOSITY OF THE MUD
    REAL :: KINVISW       ! := KINEMATIC VISCOSITY OF WATER
    REAL :: RHOW          ! := DENSITY OF WATER
    REAL :: RHOM          ! := DENSITY OF MUD
    REAL :: DM            ! := DEPTH OF MUD LAYER
    REAL :: ZETA          ! := THIS IS ZETA AS USED IN NG PG. 238. IT IS THE
    !    RATIO OF STOKES' BOUNDARY LAYER THICKNESSES,
    !    OR DELTA_M/DELTA_W
    REAL :: GAMMA         ! := THIS IS THE GAMMA USED IN NG PG. 238. THIS IS
    !  DENSITY(WATER)/DENSITY(MUD)
    REAL :: SBLTW         ! := A FUNCTION OF VISCOSITY AND FREQ
    REAL :: SBLTM         ! := A FUNCTION OF VISCOSITY AND FREQ
    REAL :: DTILDE        ! := NORMALIZED MUD DEPTH = MUD DEPTH / DELTA_M,
    !  DELTA IS THE SBLT= SQRT(2*VISC/SIGMA)
    REAL :: ZTMP
    REAL :: KDCUTOFF
    REAL :: KD

    INTEGER :: IS

    LOGICAL :: INAN

    !/ ------------------------------------------------------------------- /
    !/
#ifdef W3_S
    CALL STRACE (IENT, 'W3SBT9')
#endif
    !
    ! 0.  Initializations ------------------------------------------------ *
    !
    !     Ng (2000), Waves over soft muds.
    !     Based on code for SWAN created by Erick Rogers.
    !     Adapted for WW3 by Mark Orzech, Nov 2012.

    ! Initialize properties from mud fields if available
    IF (INFLAGS1(-2))THEN
      RHOM = MUDD(IX,IY)
    ELSE
      WRITE(NDSE,*)'RHOM NOT SET'
      CALL EXTCDE ( 1 )
    ENDIF
    IF (INFLAGS1(-1)) THEN
      DM = MUDT(IX,IY)
    ELSE
      WRITE(NDSE,*)'DM NOT SET'
      CALL EXTCDE ( 2 )
    ENDIF
    IF (INFLAGS1(0)) THEN
      KINVISM = MUDV(IX,IY)
    ELSE
      WRITE(NDSE,*)'KINVISM NOT SET'
      CALL EXTCDE ( 3 )
    ENDIF

    ROOTDG = SQRT(H_WDEPTH/GRAV)
    WGD    = ROOTDG*GRAV
    DO IS = 1, NK
      !       SND is dimensionless frequency
      SND = SIG(IS) * ROOTDG
      IF (SND .GE. 2.5) THEN
        !       ******* DEEP WATER *******
        K_ROCK  = SIG(IS) * SIG(IS) / GRAV
        CG_ROCK = 0.5 * GRAV / SIG(IS)
        NWAVE_ROCK  = 0.5
        ND_ROCK = 0.
      ELSE IF (SND.LT.1.E-6) THEN
        !       *** VERY SHALLOW WATER ***
        K_ROCK  = SND/H_WDEPTH
        CG_ROCK = WGD
        NWAVE_ROCK  = 1.
        ND_ROCK = 0.
      ELSE

        SND2  = SND*SND
        CWAVE     = SQRT(GRAV*H_WDEPTH/(SND2+1./(1.+0.666*SND2 &
             +0.445*SND2**2 -0.105*SND2**3+0.272*SND2**4)))
        K_ROCK = SIG(IS)/CWAVE

        CALL CALC_ND(K_ROCK,H_WDEPTH,SND2,ND_ROCK)

        NWAVE_ROCK = 0.5*(1.0+2.0*K_ROCK*H_WDEPTH/SINH(2.0*K_ROCK*H_WDEPTH))
        CG_ROCK= NWAVE_ROCK*CWAVE

        SND2=0
        CWAVE=0

      ENDIF

      KDCUTOFF = 10.0  ! hardwired (same as w3sbt8md)

      ! now that kh is known, we can use a definition of "deep" that is
      ! consistent with the definition used in sbot
      K_MUD=0.0
      DMW(IS)=0.0
      KD_ROCK = K_ROCK * H_WDEPTH
      ! KD_ROCK is used to determine whether we make the mud calculation
      IF((KD_ROCK.LT.KDCUTOFF).AND.(DM.GT.1.0E-5))THEN
        KINVISW=NU_WATER
        RHOW=DWAT
        ZETA=SQRT(KINVISM/KINVISW)
        GAMMA=RHOW/RHOM
        SBLTW=SQRT(2.0*KINVISW/SIG(IS))
        SBLTM=SQRT(2.0*KINVISM/SIG(IS))

        DTILDE=DM/SBLTM
        CALL NG(SIG(IS),H_WDEPTH,DTILDE,ZETA,SBLTM,GAMMA,K_ROCK,K_MUD, &
             DMW(IS))

      ELSE  !     IF ( KD_ROCK .LT. KDCUTOFF ) THEN
        K_MUD=K_ROCK
      END IF !     IF ( KD_ROCK .LT. KDCUTOFF ) THEN

      !    calculate  cg_mud, nwave_mud here
      CWAVE=SIG(IS)/K_MUD

      ZTMP=2.0*K_MUD*H_WDEPTH
      IF(ZTMP.LT.70)THEN
        ZTMP=SINH(ZTMP)
      ELSE
        ZTMP=1.0E+30
      ENDIF
      NWAVE_MUD=0.5*(1.0+2.0*K_MUD*H_WDEPTH/ZTMP)

      CG_MUD=NWAVE_MUD*CWAVE
      SND2  = SND*SND

      CALL CALC_ND(K_MUD,H_WDEPTH,SND2,ND_MUD)

      SND2=0
      CWAVE=0

      ! If we wanted to include the effects of mud on the real part of the
      ! wavnumber (as we do in SWAN), this is where we would do it.
      ! Set output variables k_out, cg_out, nwave_out, nd_out, dmw.
      !kinematics       IF(MUD)THEN !
      !kinematics          K_OUT(IS)    =K_MUD
      !kinematics          CG_OUT(IS)   =CG_MUD
      !kinematics          NWAVE_OUT(IS)=NWAVE_MUD
      !kinematics          ND_OUT(IS)   =ND_MUD
      !kinematics       ELSE ! USE ROCKY WAVENUMBER,ETC.
      !kinematics          K_OUT(IS)    =K_ROCK
      !kinematics          CG_OUT(IS)   =CG_ROCK
      !kinematics          NWAVE_OUT(IS)=NWAVE_ROCK
      !kinematics          ND_OUT(IS)   =ND_ROCK
      !kinematics          DMW(IS)=0.0
      !kinematics       ENDIF

      KD = K_MUD * H_WDEPTH
      IF ( KD .LT. KDCUTOFF ) THEN
        ! note that "IS" here is for the 1d spectrum
        SMUDWD(IS)=2.0*DMW(IS)*CG_MUD
      END IF

      ! NaN check:
      INAN = .NOT. ( DMW(IS) .GE. -HUGE(DMW(IS)) .AND. DMW(IS) &
           .LE. HUGE(DMW(IS)) )
      IF (INAN) THEN
        WRITE(*,'(/1A/)') 'W3SBT9 ERROR -- DMW(IS) IS NAN'
        WRITE(*,*)'W3SBT9: RHOM, DM, KINVISM = ',RHOM, DM, KINVISM
        WRITE(*,*)'W3SBT9: IS,NK = ',IS,NK
        WRITE(*,*)'W3SBT9: H_WDEPTH,KD,KDCUTOFF = ',H_WDEPTH,KD, KDCUTOFF
        WRITE(*,*)'W3SBT9: K_MUD,CG_MUD,NWAVE_MUD = ',K_MUD,CG_MUD,NWAVE_MUD
        CALL EXTCDE (1)
      END IF

    END DO !  DO IS = 1, NK

    !    *** store the results in the DIAGONAL arrays D and S ***
    DO IS = 1,NSPEC
      ! note that "IS" here is for the directional spectrum (2d)
      D(IS) = -SMUDWD(MAPWN(IS))
    END DO

    S = D * AC

    RETURN

  END SUBROUTINE W3SBT9

  !/ ------------------------------------------------------------------- /
  SUBROUTINE NG(SIGMA,H_WDEPTH,DTILDE,ZETA,SBLTM,GAMMA,WK,WKDR,DISS)
    !/
    !/                  +-----------------------------------+
    !/                  | WAVEWATCH III           NOAA/NCEP |
    !/                  |    E. Rogers and M. Orzech        |
    !/                  |                        FORTRAN 90 |
    !/                  | Last update :         21-Nov-2013 |
    !/                  +-----------------------------------+
    !
    !/    28-Jul-2011 : Origination.                        ( version 4.01 )
    !/    21-Nov-2013 : Preparing distribution version.     ( version 4.11 )
    !/
    !  1. Purpose :
    !
    !     Compute dissipation by viscous fluid mud using Ng (2000)
    !     (adapted from Erick Rogers code by Mark Orzech, NRL).
    !
    !  2. Method :
    !
    !  3. Parameters :
    !
    !     Parameter list
    !     ----------------------------------------------------------------
    !       SIGMA     Real  I  radian frequency (rad)
    !       H_WDEPTH  Real  I  water depth
    !       DTILDE    Real  I  normalized mud depth
    !       ZETA      Real  I  zeta as used in Ng
    !       SBLTM     Real  I  mud Stokes boundary layer thickness
    !       GAMMA     Real  I  gamma as used in Ng
    !       WK        Real  I  wavenumber w/out mud
    !       WKDR      Real  O  wavenumber w/mud
    !       DISS      Real  O  dissipation rate
    !     ----------------------------------------------------------------
    !
    !  4. Subroutines used :
    !
    !      None.
    !
    !  5. Called by :
    !
    !      Name      Type  Module   Description
    !     ----------------------------------------------------------------
    !      W3SBT9    Subr. W3SBT9MD Main routine (all freqs)
    !     ----------------------------------------------------------------
    !
    !  6. Error messages :
    !
    !       None.
    !
    !  7. Remarks :
    !     Calculations for the "B coefficients" came from a code by Jim Kaihatu
    !
    !  8. Structure :
    !
    !     See source code.
    !
    !  9. Switches :
    !
    !       None.
    !
    ! 10. Source code :
    !
    !/ ------------------------------------------------------------------- /
    !/ ------------------------------------------------------------------- /
    !/

    !
    IMPLICIT NONE

    ! INPUT VARIABLES :
    REAL, INTENT(IN)  ::  SIGMA   ! radian frequency (rad)
    REAL, INTENT(IN)  ::  H_WDEPTH! water depth, denoted "h" in Ng (m)
    REAL, INTENT(IN)  ::  DTILDE  ! normalized mud depth = mud depth / sbltm,
    ! delta is the sblt= sqrt(2*visc/sigma)
    REAL, INTENT(IN)  ::  ZETA    ! this is zeta as used in Ng pg. 238. it is
    ! the ratio of stokes' boundary layer
    ! thicknesses, or sbltm/delta_w
    REAL, INTENT(IN)  ::  GAMMA   ! this is the gamma used in Ng pg. 238.
    ! this is density(water)/density(mud)
    REAL, INTENT(IN)  ::  SBLTM   ! sbltm is what you get if you calculate
    ! sblt using the viscosity of the mud,
    ! sbltm=sqrt(2*visc_m/sigma)
    ! .....also delta_m
    REAL, INTENT(IN)  :: WK       ! unmuddy wavenumber

    ! OUTPUT VARIABLES :
    REAL, INTENT(OUT)  :: WKDR    ! muddy wavenumber
    REAL, INTENT(OUT)  :: DISS    ! dissipation rate

    ! LOCAL VARIABLES :
    REAL    :: B1  !  an Ng coefficient
    REAL    :: B2  !  an Ng coefficient
    REAL    :: B3  !  an Ng coefficient
    REAL    :: BR  !  an Ng coefficient
    REAL    :: BI  !  an Ng coefficient
    REAL    :: BRP !  an Ng coefficient
    REAL    :: BIP !  an Ng coefficient
    REAL    :: DM !  MUD DEPTH, ADDED JUNE 2 2006


    DM=DTILDE*SBLTM !  DTILDE=DM/SBLTM
    !   NOW CALCULATE Ng's B coefficients : see Ng pg 238
    B1=GAMMA*(-2.0*GAMMA**2+2.0*GAMMA-1.-ZETA**2)*SINH(DTILDE)*   &
         COSH(DTILDE)-GAMMA**2*ZETA*((COSH(DTILDE))**2+             &
         (SINH(DTILDE))**2)-(GAMMA-1.)**2*ZETA*((COSH(DTILDE))**2   &
         *(COS(DTILDE))**2+(SINH(DTILDE))**2*(SIN(DTILDE))**2)-2.0  &
         *GAMMA*(1.-GAMMA)*(ZETA*COSH(DTILDE)+GAMMA*SINH(DTILDE))   &
         *COS(DTILDE)

    B2=GAMMA*(-2.0*GAMMA**2+2.0*GAMMA-1.+ZETA**2)*SIN(DTILDE)*    &
         COS(DTILDE) -2.0*GAMMA*(1.-GAMMA)*(ZETA*SINH(DTILDE)+GAMMA &
         *COSH(DTILDE))*SIN(DTILDE)

    B3=(ZETA*COSH(DTILDE)+GAMMA*SINH(DTILDE))**2*(COS(DTILDE))**2 &
         +(ZETA*SINH(DTILDE)+GAMMA*COSH(DTILDE))**2*(SIN(DTILDE))**2

    BR=WK*SBLTM*(B1-B2)/(2.0*B3)+GAMMA*WK*DM

    BI=WK*SBLTM*(B1+B2)/(2.0*B3)
    BRP=B1/B3  ! "B_R PRIME"
    BIP=B2/B3  ! "B_I PRIME"

    !  now calculate dissipation rate and wavenumber
    DISS=-SBLTM*(BRP+BIP)*WK**2/(SINH(2.0*WK*H_WDEPTH)+2.0*WK*H_WDEPTH)
    WKDR=WK-BR*WK/(SINH(WK*H_WDEPTH)*COSH(WK*H_WDEPTH)+WK*H_WDEPTH)

    RETURN

  END SUBROUTINE NG

  !/ ------------------------------------------------------------------- /
  SUBROUTINE CALC_ND(KWAVE,H_WDEPTH,SND2,ND)
    !/ ------------------------------------------------------------------- /

    IMPLICIT NONE
    REAL, INTENT(IN)  ::  KWAVE
    REAL, INTENT(IN)  ::  H_WDEPTH
    REAL, INTENT(IN)  ::  SND2
    REAL, INTENT(OUT) ::  ND
    REAL    :: FAC1       ! LOCAL
    REAL    :: FAC2       ! LOCAL
    REAL    :: FAC3       ! LOCAL
    REAL    :: KND        ! LOCAL

    KND   = KWAVE*H_WDEPTH
    FAC1  = 2.*KND/SINH(2.*KND)
    FAC2  = SND2/KND
    FAC3  = 2.*FAC2/(1.+FAC2*FAC2)
    ND= FAC1*(0.5/H_WDEPTH - KWAVE/FAC3)

  END SUBROUTINE CALC_ND

  !/ ------------------------------------------------------------------- /
  !/
END MODULE W3SBT9MD
