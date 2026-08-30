/*
 * File: Labo2_Parte1_simu.c
 *
 * Code generated for Simulink model 'Labo2_Parte1_simu'.
 *
 * Model version                  : 4.4
 * Simulink Coder version         : 25.2 (R2025b) 28-Jul-2025
 * C/C++ source code generated on : Sat Aug 29 09:28:08 2026
 *
 * Target selection: ert.tlc
 * Embedded hardware selection: Atmel->AVR
 * Code generation objectives: Unspecified
 * Validation result: Not run
 */

#include "Labo2_Parte1_simu.h"
#include "Labo2_Parte1_simu_private.h"

/* Block signals (default storage) */
B_Labo2_Parte1_simu_T Labo2_Parte1_simu_B;

/* Block states (default storage) */
DW_Labo2_Parte1_simu_T Labo2_Parte1_simu_DW;

/* Real-time model */
static RT_MODEL_Labo2_Parte1_simu_T Labo2_Parte1_simu_M_;
RT_MODEL_Labo2_Parte1_simu_T *const Labo2_Parte1_simu_M = &Labo2_Parte1_simu_M_;

/* Model step function */
void Labo2_Parte1_simu_step(void)
{
  /* MATLABSystem: '<Root>/Analog Input' */
  Labo2_Parte1_simu_DW.obj.AnalogInDriverObj.MW_ANALOGIN_HANDLE =
    MW_AnalogIn_GetHandle(16UL);

  /* MATLABSystem: '<Root>/Analog Input' */
  MW_AnalogInSingle_ReadResult
    (Labo2_Parte1_simu_DW.obj.AnalogInDriverObj.MW_ANALOGIN_HANDLE,
     &Labo2_Parte1_simu_B.AnalogInput, MW_ANALOGIN_UINT16);

  /* Update absolute time for base rate */
  /* The "clockTick0" counts the number of times the code of this task has
   * been executed. The resolution of this integer timer is 0.4, which is the step size
   * of the task. Size of "clockTick0" ensures timer will not overflow during the
   * application lifespan selected.
   */
  Labo2_Parte1_simu_M->Timing.clockTick0++;
}

/* Model initialize function */
void Labo2_Parte1_simu_initialize(void)
{
  /* Registration code */
  rtmSetTFinal(Labo2_Parte1_simu_M, 20.0);

  /* External mode info */
  Labo2_Parte1_simu_M->Sizes.checksums[0] = (2666751546U);
  Labo2_Parte1_simu_M->Sizes.checksums[1] = (1554234093U);
  Labo2_Parte1_simu_M->Sizes.checksums[2] = (421564775U);
  Labo2_Parte1_simu_M->Sizes.checksums[3] = (3225555122U);

  {
    static const sysRanDType rtAlwaysEnabled = SUBSYS_RAN_BC_ENABLE;
    static RTWExtModeInfo rt_ExtModeInfo;
    static const sysRanDType *systemRan[2];
    Labo2_Parte1_simu_M->extModeInfo = (&rt_ExtModeInfo);
    rteiSetSubSystemActiveVectorAddresses(&rt_ExtModeInfo, systemRan);
    systemRan[0] = &rtAlwaysEnabled;
    systemRan[1] = &rtAlwaysEnabled;
    rteiSetModelMappingInfoPtr(Labo2_Parte1_simu_M->extModeInfo,
      &Labo2_Parte1_simu_M->SpecialInfo.mappingInfo);
    rteiSetChecksumsPtr(Labo2_Parte1_simu_M->extModeInfo,
                        Labo2_Parte1_simu_M->Sizes.checksums);
    rteiSetTFinalTicks(Labo2_Parte1_simu_M->extModeInfo, 50);
  }

  /* Start for MATLABSystem: '<Root>/Analog Input' */
  Labo2_Parte1_simu_DW.obj.matlabCodegenIsDeleted = false;
  Labo2_Parte1_simu_DW.obj.isInitialized = 1L;
  Labo2_Parte1_simu_DW.obj.AnalogInDriverObj.MW_ANALOGIN_HANDLE =
    MW_AnalogInSingle_Open(16UL);
  Labo2_Parte1_simu_DW.obj.isSetupComplete = true;
}

/* Model terminate function */
void Labo2_Parte1_simu_terminate(void)
{
  /* Terminate for MATLABSystem: '<Root>/Analog Input' */
  if (!Labo2_Parte1_simu_DW.obj.matlabCodegenIsDeleted) {
    Labo2_Parte1_simu_DW.obj.matlabCodegenIsDeleted = true;
    if ((Labo2_Parte1_simu_DW.obj.isInitialized == 1L) &&
        Labo2_Parte1_simu_DW.obj.isSetupComplete) {
      Labo2_Parte1_simu_DW.obj.AnalogInDriverObj.MW_ANALOGIN_HANDLE =
        MW_AnalogIn_GetHandle(16UL);
      MW_AnalogIn_Close
        (Labo2_Parte1_simu_DW.obj.AnalogInDriverObj.MW_ANALOGIN_HANDLE);
    }
  }

  /* End of Terminate for MATLABSystem: '<Root>/Analog Input' */
}

/*
 * File trailer for generated code.
 *
 * [EOF]
 */
