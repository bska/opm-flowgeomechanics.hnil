###########################################################################
#                                                                         #
# Note: The bulk of the build system is located in the cmake/ directory.  #
#       This file only contains the specializations for this particular   #
#       project. Most likely you are interested in editing one of these   #
#       files instead:                                                    #
#                                                                         #
#       dune.module                Name and version number                #
#       CMakeLists_files.cmake     Path of source files                   #
#       ${project}-prereqs.cmake   Dependencies                           #
#                                                                         #
###########################################################################

cmake_minimum_required(VERSION 3.26)

# Mandatory call to project
project(opm-flowgeomechanics C CXX)

# ---------------------------------------------------------------------------
# User options

option(SIBLING_SEARCH "Search for other modules in sibling directories?" ON)
option(USE_TRACY_PROFILER "Enable tracy profiling" OFF)

# ---------------------------------------------------------------------------
# Prerequisites for opm-flowgeomechanics library

macro(opm-flowgeomechanics_prereqs_hook)
  target_link_libraries(opmflowgeomechanics
    PUBLIC
      opmupscaling
      opmsimulators
      CGAL::CGAL
      GMP::gmp
      GMP::gmpxx
      MPI::MPI_C MPI::MPI_CXX
  )

  if(USE_TRACY_PROFILER)
    find_package(Tracy)
  endif()
endmacro()

# ---------------------------------------------------------------------------

macro(opm-flowgeomechanics_config_hook)
  # Define DUNE_*_VERSION_* symbols in <config.h>
  #
  # These are needed for Dune::GridFactory's FoamGrid implementation.
  opm_need_version_of("dune-common")
  opm_need_version_of("dune-istl")
endmacro()

# ---------------------------------------------------------------------------
# Main library and example utilities

macro(opm-flowgeomechanics_targets_hook)
  # Library needs <config.h>.  Tell build where to find it...
  target_include_directories(opmflowgeomechanics
    PRIVATE ${PROJECT_BINARY_DIR}
  )

  opm_add_library(
    TARGET
      moduleVersionGeoMech
    TYPE
      OBJECT
    SOURCES
      opm/simulators/utils/moduleVersion.cpp
  )

  # Very strictly speaking, moduleVersionGeoMech depends only on the
  # custom "update-version" target from OpmLibMain since it uses the
  # generated file "${PROJECT_BINARY_DIR}/project-verion.h" as an
  # input.  However, "update-version" is not available in the "super
  # build" setup, so we instead make sure that opmflowgeomechanics is
  # fully built before we build moduleVersionGeoMech.
  add_dependencies(moduleVersionGeoMech opmflowgeomechanics)

  add_executable(flow_geomech)
  add_executable(flow_energy_geomech)
  add_executable(padmodel)

  opm_add_target_options(TARGET flow_geomech)
  opm_add_target_options(TARGET flow_energy_geomech)
  opm_add_target_options(TARGET padmodel)

  target_sources(flow_geomech
    PRIVATE
      examples/flow_geomech.cpp
  )

  target_sources(flow_energy_geomech
    PRIVATE
      examples/flow_energy_geomech.cpp
  )

  target_sources(padmodel
    PRIVATE
      examples/padmodel.cpp
  )

  target_link_libraries(padmodel
    PRIVATE
      opmsimulators
  )

  foreach(simulator flow_geomech flow_energy_geomech)
    target_link_libraries(${simulator}
      PRIVATE
        opmflowgeomechanics
        $<TARGET_OBJECTS:moduleVersionGeoMech>
    )
    target_include_directories(${simulator}
      PRIVATE ${PROJECT_BINARY_DIR}
    )
  endforeach()

  if(USE_TRACY_PROFILER AND Tracy_FOUND)
    foreach(simulator flow_geomech flow_energy_geomech)
      target_compile_definitions(${simulator} PUBLIC USE_TRACY=1)
      target_link_libraries(${simulator}
        PRIVATE
          Tracy::TracyClient
      )
    endforeach()
  else()
    foreach(simulator flow_geomech flow_energy_geomech)
      target_compile_definitions(${simulator} PUBLIC USE_TRACY=0)
    endforeach()
  endif()
endmacro()

# ---------------------------------------------------------------------------
# Unit and regression tests

function(add_mechtest_compareECLFiles)
  set(oneValueArgs CASENAME FILENAME
    SIMULATOR BIN_PATH
    ABS_TOL REL_TOL
    DIR DIR_PREFIX
    PREFIX RESTART_STEP
    RESTART_SCHED)
  set(multiValueArgs TEST_ARGS)
  cmake_parse_arguments(PARAM "$" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  set(RESULT_PATH ${CMAKE_CURRENT_SOURCE_DIR}/result/${PARAM_CASENAME})
  set(TEST_ARGS ${PARAM_TEST_ARGS})

  set(DRIVER_ARGS
    -i ${CMAKE_CURRENT_SOURCE_DIR}/data
    -r ${RESULT_PATH}
    -b ${PROJECT_BINARY_DIR}/bin
    -f ${PARAM_FILENAME}
    -a ${PARAM_ABS_TOL}
    -t ${PARAM_REL_TOL}
    -c $<TARGET_FILE:compareECL>
    -o ${PARAM_CASENAME}
  )

  opm_add_test(${PARAM_CASENAME}_${PARAM_SIMULATOR}+${PARAM_FILENAME} NO_COMPILE
    EXE_NAME ${PARAM_SIMULATOR}
    DRIVER_ARGS ${DRIVER_ARGS}
    TEST_ARGS ${TEST_ARGS}
  )

  set_tests_properties(${PARAM_CASENAME}_${PARAM_SIMULATOR}+${PARAM_FILENAME}
    PROPERTIES
      DIRNAME ${PARAM_DIR}
      FILENAME ${PARAM_FILENAME}
      SIMULATOR ${PARAM_SIMULATOR}
      TESTNAME ${PARAM_CASENAME}
  )
endfunction()

macro(opm-flowgeomechanics_tests_hook)
  add_executable(test_foamgrid)
  add_executable(test_vem_elements)
  add_executable(paramtest)
  add_executable(test_trimesh)
  add_executable(test_gridstretch)
  add_executable(coupled_standalone_test)
  add_executable(standalone_sim_test)
  add_executable(test_fracture_pressure_ad)
  add_executable(test_patch_recovery)
  add_executable(test_ddm_assembly)
  add_executable(example_penny_crack_ddm)

  # -------------------------------------------------------------------------

  target_sources(test_foamgrid
    PRIVATE
    examples/test_foamgrid.cpp
  )

  target_sources(test_vem_elements
    PRIVATE
    examples/test_vem_elements.cpp
  )

  target_sources(paramtest
    PRIVATE
    examples/paramtest.cpp
  )

  target_sources(test_trimesh
    PRIVATE
    examples/test_trimesh.cpp
  )

  target_sources(test_gridstretch
    PRIVATE
    examples/test_gridstretch.cpp
  )

  target_sources(coupled_standalone_test
    PRIVATE
    examples/coupled_standalone_test.cpp
  )

  target_sources(standalone_sim_test
    PRIVATE
    examples/standalone_sim_test.cpp
  )

  target_sources(test_fracture_pressure_ad
    PRIVATE
    examples/test_fracture_pressure_ad.cpp
  )

  target_sources(test_patch_recovery
    PRIVATE
    examples/test_patch_recovery.cpp
  )

  target_sources(test_ddm_assembly
    PRIVATE
    examples/test_ddm_assembly.cpp
  )

  target_sources(example_penny_crack_ddm
    PRIVATE
    examples/example_penny_crack_ddm.cpp
  )

  # -------------------------------------------------------------------------

  target_link_libraries(test_foamgrid
    PRIVATE
    opmsimulators
    opmupscaling
  )

  target_link_libraries(test_vem_elements
    PRIVATE
    opmflowgeomechanics
  )

  target_link_libraries(paramtest
    PRIVATE
    opmflowgeomechanics
  )

  target_link_libraries(test_trimesh
    PRIVATE
    opmflowgeomechanics
  )

  target_link_libraries(test_gridstretch
    PRIVATE
    opmflowgeomechanics
  )

  target_link_libraries(coupled_standalone_test
    PRIVATE
    opmflowgeomechanics
  )

  target_link_libraries(standalone_sim_test
    PRIVATE
    opmflowgeomechanics
  )

  target_link_libraries(test_fracture_pressure_ad
    PRIVATE
    opmflowgeomechanics
  )

  target_link_libraries(test_patch_recovery
    PRIVATE
    opmflowgeomechanics
  )

  target_link_libraries(test_ddm_assembly
    PRIVATE
    opmflowgeomechanics
  )

  target_link_libraries(example_penny_crack_ddm
    PRIVATE
    opmflowgeomechanics
  )

  if(USE_TRACY_PROFILER AND Tracy_FOUND)
    target_link_libraries(test_vem_elements
      PRIVATE
      Tracy::TracyClient
    )
  endif()

  # Hack: These tests need <config.h>.  Tell build where to find it.
  # While here, also apply the common options for all OPM executables
  # (e.g., C++20 mode and binaries in ${PROJECT_BINARY_DIR}/bin).
  foreach(tst
      test_foamgrid
      test_vem_elements
      paramtest test_trimesh
      test_gridstretch
      coupled_standalone_test
      standalone_sim_test
      test_fracture_pressure_ad
      test_patch_recovery
      test_ddm_assembly
      example_penny_crack_ddm)
    target_include_directories(${tst} PRIVATE ${PROJECT_BINARY_DIR})
    opm_add_target_options(TARGET ${tst})
  endforeach()

  # -------------------------------------------------------------------------

  add_test(NAME Test.FracturePressureAD
    COMMAND test_fracture_pressure_ad
  )

  add_test(NAME Test.DDMAssembly
    COMMAND test_ddm_assembly
  )

  add_test(NAME Test.DDM.PennyCrack
    COMMAND example_penny_crack_ddm
  )

  add_test(NAME Unit.VemElements
    COMMAND test_vem_elements
  )

  add_test(NAME Unit.Trimesh.IrregularGrid
    COMMAND test_trimesh 1
  )

  add_test(NAME Unit.Trimesh.GridRefinement
    COMMAND test_trimesh 3
  )

  add_test(NAME Unit.PatchRecovery
    COMMAND test_patch_recovery
  )

  # -------------------------------------------------------------------------

  set(Test_NumProc 4)
  if (MPIEXEC_MAX_NUMPROCS LESS Test_NumProc)
    set(Test_NumProc ${MPIEXEC_MAX_NUMPROCS})
  endif()

  # -------------------------------------------------------------------------

  add_test(NAME Run.Blackoil_Thermal_BC.Parallel
    COMMAND
    ${MPIEXEC_EXECUTABLE}
    ${MPIEXEC_NUMPROC_FLAG} ${Test_NumProc}
    ${MPIEXEC_PREFLAGS}
    $<SHELL_PATH:$<TARGET_FILE:flow_energy_geomech>>
    ${MPIEXEC_POSTFLAGS}
    --ecl-deck-file-name=${CMAKE_CURRENT_SOURCE_DIR}/data/MECHTEST/BLACKOILTHERMAL_BC.DATA
    --enable-esmry=false
    --output-dir=results/np-${Test_NumProc}/flow_energy_geomech/Blackoil_Thermal_BC
  )

  set_tests_properties(Run.Blackoil_Thermal_BC.Parallel
    PROPERTIES
    PROCESSORS ${Test_NumProc}
    FIXTURES_SETUP Generate_SimResults
  )

  # -------------------------------------------------------------------------

  add_test(NAME Run.SPE1_Geomech_Mini.Parallel
    COMMAND
    ${MPIEXEC_EXECUTABLE}
    ${MPIEXEC_NUMPROC_FLAG} ${Test_NumProc}
    ${MPIEXEC_PREFLAGS}
    $<SHELL_PATH:$<TARGET_FILE:flow_geomech>>
    ${MPIEXEC_POSTFLAGS}
    --ecl-deck-file-name=${CMAKE_CURRENT_SOURCE_DIR}/data/SPE1CASE2_MECH_MINI.DATA
    --enable-esmry=false
    --add-corners=true
    --output-dir=results/np-${Test_NumProc}/flow_geomech/SPE1_Geomech_Mini
  )

  set_tests_properties(Run.SPE1_Geomech_Mini.Parallel
    PROPERTIES
    PROCESSORS ${Test_NumProc}
  )

  # -------------------------------------------------------------------------

  add_test(NAME Run.SIMPLE_MECH.EnergyGeomech
    COMMAND
    $<SHELL_PATH:$<TARGET_FILE:flow_geomech>>
    ${CMAKE_CURRENT_SOURCE_DIR}/data/SIMPLE_MECH_NX_11_NY_11_NZ_25.DATA
    --parameter-file=${CMAKE_CURRENT_SOURCE_DIR}/data/myparamsfrac.ini
    --enable-esmry=false
    --output-dir=test
    --linear-solver-mech=${CMAKE_CURRENT_SOURCE_DIR}/data/amgmechsolverhypre_geosxcpu_new_nv.json
  )

  set_tests_properties(Run.SIMPLE_MECH.EnergyGeomech
    PROPERTIES
    PROCESSORS 1
  )

  # -------------------------------------------------------------------------

  add_test(NAME Run.SIMPLE_MECH.EnergyGeomech.Parallel
    COMMAND
    ${MPIEXEC_EXECUTABLE}
    ${MPIEXEC_NUMPROC_FLAG} ${Test_NumProc}
    ${MPIEXEC_PREFLAGS}
    $<SHELL_PATH:$<TARGET_FILE:flow_geomech>>
    ${MPIEXEC_POSTFLAGS}
    ${CMAKE_CURRENT_SOURCE_DIR}/data/SIMPLE_MECH_NX_11_NY_11_NZ_25.DATA
    --parameter-file=${CMAKE_CURRENT_SOURCE_DIR}/data/myparamsfrac.ini
    --linear-solver-mech=${CMAKE_CURRENT_SOURCE_DIR}/data/amgmechsolverhypre_geosxcpu_new_nv.json
    --add-corners=true
    --edge-conformal=true
    --enable-esmry=false
    --output-dir=results/np-${Test_NumProc}/flow_energy_geomech/SIMPLE_MECH
  )

  set_tests_properties(Run.SIMPLE_MECH.EnergyGeomech.Parallel
    PROPERTIES
    PROCESSORS ${Test_NumProc}
  )

  # -------------------------------------------------------------------------

  add_test(NAME Run.SIMPLE_MECH_FRAC_MPI.EnergyGeomech
    COMMAND
    $<SHELL_PATH:$<TARGET_FILE:flow_geomech>>
    ${CMAKE_CURRENT_SOURCE_DIR}/data/SIMPLE_MECH_NX_11_NY_11_NZ_25_FRAC.DATA
    --parameter-file=${CMAKE_CURRENT_SOURCE_DIR}/data/myparamsfrac.ini
    --output-dir=test_default
    --add-corners=true
    --enable-esmry=false
    --linear-solver-mech=${CMAKE_CURRENT_SOURCE_DIR}/data/amgmechsolverhypre_geosxcpu_new_nv.json
  )

  set_tests_properties(Run.SIMPLE_MECH_FRAC_MPI.EnergyGeomech
    PROPERTIES
    PROCESSORS ${Test_NumProc}
  )

  # -------------------------------------------------------------------------

  add_test(NAME Run.SIMPLE_MECH_FRAC_THREAD.EnergyGeomech
    COMMAND
    $<SHELL_PATH:$<TARGET_FILE:flow_geomech>>
    ${CMAKE_CURRENT_SOURCE_DIR}/data/SIMPLE_MECH_NX_11_NY_11_NZ_25_FRAC.DATA
    --parameter-file=${CMAKE_CURRENT_SOURCE_DIR}/data/myparamsfrac.ini
    --output-dir=test_default
    --add-corners=true
    --enable-esmry=false
    --threads-per-process=4
    --linear-solver-mech=${CMAKE_CURRENT_SOURCE_DIR}/data/amgmechsolverhypre_geosxcpu_new_nv.json
  )

  set_tests_properties(Run.SIMPLE_MECH_FRAC_THREAD.EnergyGeomech
    PROPERTIES
    PROCESSORS 1
  )

  # -------------------------------------------------------------------------

  add_test(NAME Run.SIMPLE_MECH_FRAC_RESET.EnergyGeomech
    COMMAND
    $<SHELL_PATH:$<TARGET_FILE:flow_geomech>>
    ${CMAKE_CURRENT_SOURCE_DIR}/data/SIMPLE_MECH_NX_11_NY_11_NZ_25_FRAC_RESET.DATA
    --parameter-file=${CMAKE_CURRENT_SOURCE_DIR}/data/myparamsfrac_frac.ini
    --output-dir=test_frac_reset
    --add-corners=true
    --enable-esmry=false
    --linear-solver-mech=${CMAKE_CURRENT_SOURCE_DIR}/data/amgmechsolverhypre_geosxcpu_new_nv.json
  )

  # -------------------------------------------------------------------------

  add_test(NAME Run.SIMPLE_MECH_FRAC_RESET_SEQ.EnergyGeomech
    COMMAND
    $<SHELL_PATH:$<TARGET_FILE:flow_geomech>>
    ${CMAKE_CURRENT_SOURCE_DIR}/data/SIMPLE_MECH_NX_11_NY_11_NZ_25_FRAC_RESET.DATA
    --parameter-file=${CMAKE_CURRENT_SOURCE_DIR}/data/myparamsfrac_frac.ini
    --output-dir=test_frac_reset_seq
    --fracture-param-file=${CMAKE_CURRENT_SOURCE_DIR}/data/fracture_simple_bhp_seq_nverbose.json
    --add-corners=true
    --enable-esmry=false
    --linear-solver-mech=${CMAKE_CURRENT_SOURCE_DIR}/data/amgmechsolverhypre_geosxcpu_new_nv.json
  )

  set_tests_properties(Run.SIMPLE_MECH_FRAC_RESET.EnergyGeomech
    PROPERTIES
    PROCESSORS 1
  )

  # =========================================================================

  opm_set_test_driver(${PROJECT_SOURCE_DIR}/tests/run-mechRegressionTest.sh "")

  set(abs_tol 2e-2)
  set(rel_tol 1e-5)

  add_mechtest_compareECLFiles(CASENAME REGTEST_geomech
    FILENAME SIMPLE_MECH_NX_11_NY_11_NZ_25
    SIMULATOR flow_geomech
    ABS_TOL ${abs_tol}
    REL_TOL ${rel_tol}
    DIR ${CMAKE_CURRENT_SOURCE_DIR}/data/
    PREFIX geomech
    TEST_ARGS --enable-esmry=false
  )

  add_mechtest_compareECLFiles(CASENAME REGTEST_geomech_frac
    FILENAME SIMPLE_MECH_NX_11_NY_11_NZ_25_FRAC
    SIMULATOR flow_geomech
    ABS_TOL ${abs_tol}
    REL_TOL ${rel_tol}
    DIR ${CMAKE_CURRENT_SOURCE_DIR}/data/
    PREFIX geomech_frac
    TEST_ARGS --enable-esmry=false
  )

  add_mechtest_compareECLFiles(CASENAME REGTEST_geomech_frac_seq_bhp
    FILENAME SIMPLE_MECH_NX_11_NY_11_NZ_25_FRAC_SEQ
    SIMULATOR flow_geomech
    ABS_TOL ${abs_tol}
    REL_TOL ${rel_tol}
    DIR ${CMAKE_CURRENT_SOURCE_DIR}/data/
    PREFIX geomech_frac_seq_bhp
    TEST_ARGS --parameter-file=${CMAKE_CURRENT_SOURCE_DIR}/data/myparamsfrac.ini
    --fracture-param-file=${CMAKE_CURRENT_SOURCE_DIR}/data/fracture_simple_bhp_seq_nverbose.json
    --enable-write-all-solutions=true
    --linear-solver-mech=${CMAKE_CURRENT_SOURCE_DIR}/data/amgmechsolverhypre_geosxcpu_new_nv.json
    --threads-per-process=4
    --enable-esmry=false
  )

  add_mechtest_compareECLFiles(CASENAME REGTEST_geomech_frac_seq_rate
    FILENAME SIMPLE_MECH_NX_11_NY_11_NZ_25_FRAC_SEQ
    SIMULATOR flow_geomech
    ABS_TOL ${abs_tol}
    REL_TOL ${rel_tol}
    DIR ${CMAKE_CURRENT_SOURCE_DIR}/data/
    PREFIX geomech_frac_seq_rate
    TEST_ARGS --parameter-file=${CMAKE_CURRENT_SOURCE_DIR}/data/myparamsfrac.ini
    --fracture-param-file=${CMAKE_CURRENT_SOURCE_DIR}/data/fracture_simple_rate_seq_nverbose.json
    --linear-solver-mech=${CMAKE_CURRENT_SOURCE_DIR}/data/amgmechsolverhypre_geosxcpu_new_nv.json
    --threads-per-process=4
    --enable-esmry=false
  )

endmacro()

# ---------------------------------------------------------------------------
# Hook up to main OPM build system in opm-common

if(SIBLING_SEARCH AND NOT opm-common_DIR)
  # guess the sibling dir
  get_filename_component(_leaf_dir_name ${PROJECT_BINARY_DIR} NAME)
  get_filename_component(_parent_full_dir ${PROJECT_BINARY_DIR} DIRECTORY)
  get_filename_component(_parent_dir_name ${_parent_full_dir} NAME)
  #Try if <module-name>/<build-dir> is used
  get_filename_component(_modules_dir ${_parent_full_dir} DIRECTORY)
  if(IS_DIRECTORY ${_modules_dir}/opm-common/${_leaf_dir_name})
    set(opm-common_DIR ${_modules_dir}/opm-common/${_leaf_dir_name})
  else()
    string(REPLACE ${PROJECT_NAME} opm-common _opm_common_leaf ${_leaf_dir_name})
    if(NOT _leaf_dir_name STREQUAL _opm_common_leaf
	AND IS_DIRECTORY ${_parent_full_dir}/${_opm_common_leaf})
      # We are using build directories named <prefix><module-name><postfix>
      set(opm-common_DIR ${_parent_full_dir}/${_opm_common_leaf})
    elseif(IS_DIRECTORY ${_parent_full_dir}/opm-common)
      # All modules are in a common build dir
      set(opm-common_DIR "${_parent_full_dir}/opm-common")
    endif()
  endif()
endif()

if(opm-common_DIR AND NOT IS_DIRECTORY ${opm-common_DIR})
  message(WARNING "Value ${opm-common_DIR} passed to variable "
    "opm-common_DIR is not a directory")
endif()

find_package(opm-common REQUIRED)

# Project information is in dune.module.  Read this file and set
# variables.  We cannot generate dune.module since it is read by
# dunecontrol before the build starts, so it makes sense to keep the
# data there then.
include (OpmInit)

# All setup common to the OPM library modules is done here.
include (OpmLibMain)
