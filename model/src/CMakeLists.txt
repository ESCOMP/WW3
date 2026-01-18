cmake_minimum_required(VERSION 3.12)
project(wav Fortran)

message("Using CIME in ${CIMEROOT} with compiler ${COMPILER}")

include(${CASEROOT}/Macros.cmake)
if (MPILIB STREQUAL mpi-serial)
  set(CMAKE_Fortran_COMPILER ${SFC})
  set(CMAKE_C_COMPILER ${SCC})
else()
  set(CMAKE_Fortran_COMPILER ${MPIFC})
  set(CMAKE_C_COMPILER ${MPICC})
endif()
set(CMAKE_Fortran_FLAGS "${FFLAGS} ${CPPDEFS} -I${LIBROOT}/include -I${LIBROOT}/finclude -I${LIBROOT}/nuopc/esmf/${NINST_VALUE}/include")

#-------------------------
# Set ESMF_F90COMPILEPATHS
#-------------------------
# convert esmf.mk makefile variables to cmake variables until ESMF
# provides proper cmake package
if (DEFINED ENV{ESMFMKFILE})
  message("ESMFMKFILE:   $ENV{ESMFMKFILE}")
else()
  message(FATAL_ERROR "ESMFMKFILE env variable is not defined")
endif()
set(ESMFMKFILE $ENV{ESMFMKFILE})
file(STRINGS ${ESMFMKFILE} esmf_mk_text)
foreach(line ${esmf_mk_text})
  string(REGEX REPLACE "^[ ]+" "" line ${line}) # strip leading spaces
  if (line MATCHES "^ESMF_*")                   # process only line starting with ESMF_
    string(REGEX MATCH "^ESMF_[^=]+" esmf_name ${line})
    string(REPLACE "${esmf_name}=" "" emsf_value ${line})
    set(${esmf_name} "${emsf_value}")
  endif()
endforeach()
string(REPLACE "-I" "" ESMF_F90COMPILEPATHS ${ESMF_F90COMPILEPATHS})
string(REPLACE " " ";" ESMF_F90COMPILEPATHS ${ESMF_F90COMPILEPATHS})
message("ESMF_F90COMPILEPATHS:   ${ESMF_F90COMPILEPATHS}")

#-------------------------
# Determine switches
#-------------------------
list(APPEND switches "CESMCOUPLED" "DIST" "MPI" "FLX0" "SEED" "ST4" "STAB0" "NL1" "BT1" "DB1" "MLIM" "FLD2" "TR0" "BS0" "RWND" "WNX1" "WNT1" "CRX1" "CRT1" "O0" "O1" "O2" "O3" "O4" "O5" "O6" "O7" "O14" "O15" "IS0" "REF0" "NOGRB" "IC4" "NCO")

if (DEFINED USE_PR3)
  list(APPEND switches PR3 UQ)
elseif (DEFINED USE_PR1)
  list(APPEND switches PR1)
else()
  message(FATAL_ERROR "either USE_PR3 or USE_PR1 must be defined")
endif()

if (DEFINED USE_UNSTRUCT)
  list(APPEND switches "PDLIB" "METIS")
###else()
###  list(APPEND switches "OMPG"  "OMPH")
endif()

# Set compiler flags.
if(CMAKE_Fortran_COMPILER_ID MATCHES "^(Intel)$")
  set(compile_flags -no-fma -ip -g -traceback -i4 -real-size 32 -fp-model precise
    -assume byterecl -fno-alias -fno-fnalias)
  # -sox only works on Linux
  if(LINUX)
    list(APPEND compile_flags -sox)
  endif()
  set(compile_flags_release -O3)
  # SHELL: prefix fixes CMake attempting to de-duplicate the repeated uses of 'all' in -warn, -debug, -check
  # See https://cmake.org/cmake/help/latest/command/target_compile_options.html#option-de-duplication
  set(compile_flags_debug -O0 "SHELL:-debug all" "SHELL:-warn all" "SHELL:-check all" -check noarg_temp_created -fp-stack-check -heap-arrays -traceback -fpe0)

  if(APPLE)
    # The linker on macOS does not include `common symbols` (usually module variables without a default value) by default
    # Passing the -c flag includes them and fixes an error with undefined symbols
    # Only ifort marks these symbols as common, compared to GCC
    set(CMAKE_Fortran_ARCHIVE_FINISH "<CMAKE_RANLIB> -c <TARGET>")
    set(CMAKE_C_ARCHIVE_FINISH "<CMAKE_RANLIB> -c <TARGET>")
  endif()

elseif(CMAKE_Fortran_COMPILER_ID MATCHES "^(IntelLLVM)$")
  set(compile_flags -no-fma -g -traceback -i4 -real-size 32 -fp-model precise -assume byterecl -fno-alias)
  set(compile_flags_release -O3)
  # SHELL: prefix fixes CMake attempting to de-duplicate the repeated uses of 'all' in -warn, -debug, -check
  # See https://cmake.org/cmake/help/latest/command/target_compile_options.html#option-de-duplication
  set(compile_flags_debug -O0 "SHELL:-debug all" "SHELL:-warn all" "SHELL:-check all" -check noarg_temp_created -fp-stack-check -heap-arrays -traceback -fpe0)

  if(APPLE)
    # The linker on macOS does not include `common symbols` (usually module variables without a default value) by default
    # Passing the -c flag includes them and fixes an error with undefined symbols
    # Only ifort marks these symbols as common, compared to GCC
    set(CMAKE_Fortran_ARCHIVE_FINISH "<CMAKE_RANLIB> -c <TARGET>")
    set(CMAKE_C_ARCHIVE_FINISH "<CMAKE_RANLIB> -c <TARGET>")
  endif()

elseif(CMAKE_Fortran_COMPILER_ID MATCHES "^(GNU)$")
  set(compile_flags -g -fno-second-underscore -ffree-line-length-none)
  set(compile_flags_release -O3)
  set(compile_flags_debug -Wall -fcheck=all -ffpe-trap=invalid,zero,overflow -frecursive -fbacktrace)

  if(${CMAKE_Fortran_COMPILER_VERSION} VERSION_GREATER_EQUAL 10)
    list(APPEND compile_flags -fallow-argument-mismatch)
  endif()

elseif(CMAKE_Fortran_COMPILER_ID MATCHES "PGI")
  set(compile_flags -g -i4 -r4 -Kieee)
  set(compile_flags_release -O3)
  set(compile_flags_debug -O0 -Mbounds -Mchkfpstk -Mchkstk -Mdalign -Mdclchk -Mdepchk -Miomutex -Ktrap=fp -Mrecursive -traceback)

  if(${CMAKE_Fortran_COMPILER_VERSION} VERSION_GREATER_EQUAL 10)
    list(APPEND compile_flags -fallow-argument-mismatch -fallow-invalid-boz)
  endif()

elseif(CMAKE_Fortran_COMPILER_ID MATCHES "Cray")
  # TODO: Where do we set -homp for OpenMP compiles?
  set(compile_flags -g -sdefault32 -eg)
  set(compile_flags_release -O3)
  set(compile_flags_debug -O0 -Rbcps -Ktrap=fp)
endif()


#-------------------------
# Include list of src files to make file more readable
# defines variables "ftn_src", "nuopc_mesh_cap_src", "pdlib_src", "scrip_src", and "scripnc_src"
#-------------------------
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/src_list.cmake)

list(APPEND ftn_src ${nuopc_mesh_cap_src})

# Executables to build if NetCDF is found
set(netcdf_programs ww3_ounf ww3_ounp ww3_bounc ww3_trnc ww3_prnc)

if("OASIS" IN_LIST switches)
  find_package(OASIS REQUIRED)
  set(LINK_OASIS TRUE)
endif()

if(NETCDF)
  if("netcdf" IN_LIST EXCLUDE_FIND)
    # NetCDF library flags provided by compiler or wrapper script: don't search
    set(NetCDF_Fortran_FOUND TRUE)
    message(WARNING "Not searching for NetCDF library - please ensure correct flags are provided by your compiler/wrapper")
  else()
    find_package(NetCDF REQUIRED COMPONENTS Fortran)
  endif()
endif()

if(NetCDF_Fortran_FOUND)
  list(APPEND ftn_src w3ounfmetamd.F90)
  set(LINK_NETCDF TRUE)
  list(APPEND programs ${netcdf_programs})
endif()

if(UFS_CAP)
  # Don't search for ESMF if target already exists (when build WW3 as UFS submodule)
  if (NOT TARGET esmf)
    find_package(ESMF MODULE REQUIRED)
  endif()

  if(UFS_CAP STREQUAL "MULTI_ESMF")
    list(APPEND ftn_src ${esmf_multi_cap_src})
  elseif(UFS_CAP STREQUAL "NUOPC_MESH")
    list(APPEND ftn_src ${nuopc_mesh_cap_src})
  endif()

  set(LINK_ESMF TRUE)
  # Don't build executables when building WW3 ESMF library
  set(programs "")
endif()

set_property(SOURCE w3initmd.F90
  APPEND
  PROPERTY COMPILE_DEFINITIONS
  "__WW3_SWITCHES__=\'${switch_strings}\'"
  )

if("OMPG" IN_LIST switches)
  find_package(OpenMP REQUIRED COMPONENTS Fortran)
  set(LINK_OPENMP TRUE)
endif()

if("MPI" IN_LIST switches)
  find_package(MPI REQUIRED COMPONENTS Fortran)
  set(LINK_MPI TRUE)
endif()

if("PIO" IN_LIST switches)
  target_sources(ww3_lib PRIVATE ${pio_src})
endif()

# Handle PDLIB, SCRIP, SCRIPNC build files directly instead of through configuration file
if("PDLIB" IN_LIST switches)
  list(APPEND ftn_src ${pdlib_src})
  if("SCOTCH" IN_LIST switches)
    #find_package(SCOTCH REQUIRED)
    #target_link_libraries(ww3_lib PUBLIC PTSCOTCHparmetis::PTSCOTCHparmetis)
  elseif("METIS" IN_LIST switches)
    #find_package(ParMETIS REQUIRED)
    #target_link_libraries(ww3_lib PUBLIC ParMETIS::ParMETIS)
  else()
    message(FATAL_ERROR "PDLIB requires METIS or SCOTCH library for domain decomposition")
 endif()
endif()

if("SCRIP" IN_LIST switches)
  list(APPEND ftn_src ${scrip_src})
endif()

if("SCRIPNC" IN_LIST switches OR "OASIS" IN_LIST switches OR "TRKNC" IN_LIST switches OR "BIN2NC" IN_LIST switches)
  if(NOT NetCDF_Fortran_FOUND)
	  message(FATAL_ERROR "Cannot build SCRIPNC, OASIS, TRKNC, or BIN2NC without NetCDF")
  endif()
endif()

#-------------------------
# Determine switch specific files
# Include check_switches as a function for less verbosity in this CMakeLists.txt
#-------------------------
message(STATUS "switches are : ${switches}")
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/check_switches.cmake)
check_switches("${switches}" switch_files)

message(STATUS "---")
message(STATUS "list of always source files is : ${ftn_src}")
message(STATUS "list of switch files is : ${switch_files}")
message(STATUS "---")

#-------------------------
# Now check in SourceMods to see if the file should be used instead
#-------------------------
list(APPEND srcfiles ${ftn_src} ${switch_files})
foreach(file ${srcfiles} )
  if(EXISTS "${CASEROOT}/SourceMods/src.ww3/${file}")
    message("Using ${file} from ${CASEROOT}/SourceMods/src.ww3")
    list(REMOVE_ITEM srcfiles ${file})
    list(APPEND srcfiles "${CASEROOT}/SourceMods/src.ww3/${file}")
    message(STATUS "Using ${file} from ${CASEROOT}/SourceMods/src.ww3")
  endif()
endforeach()

#-------------------------
# Determine target library wav
#-------------------------
add_library(wav ${srcfiles})
set_target_properties(wav PROPERTIES Fortran_MODULE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/mod)
target_include_directories(wav PRIVATE ${ESMF_F90COMPILEPATHS})
target_include_directories(wav
  PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/mod>
  $<INSTALL_INTERFACE:mod>)
target_compile_options(wav PRIVATE ${compile_flags})

# Link deferred dependencies
if(LINK_OASIS)
  target_link_libraries(wav PUBLIC OASIS::OASIS)
endif()
if(LINK_NETCDF AND TARGET NetCDF::NetCDF_Fortran)
  target_link_libraries(wav PUBLIC NetCDF::NetCDF_Fortran)
endif()
if(LINK_ESMF)
  target_link_libraries(wav PUBLIC esmf)
endif()
if(LINK_OPENMP)
  target_link_libraries(wav PUBLIC OpenMP::OpenMP_Fortran)
endif()
if(LINK_MPI)
  target_link_libraries(wav PUBLIC MPI::MPI_Fortran)
endif()

#-------------------------
# Determine compile definitions for wav
#-------------------------
foreach(switch ${switches})
  target_compile_definitions(wav PUBLIC W3_${switch})
endforeach()
add_compile_definitions(ENDIANNESS="big_endian")

message("CMAKE_CURRENT_BINARY_DIR is ${CMAKE_CURRENT_BINARY_DIR}")
message("PROJECT_BINARY_DIR is ${PROJECT_BINARY_DIR}")

# Executables to always build
add_executable(ww3_grid ww3_grid.F90)
target_link_libraries(ww3_grid PRIVATE wav)

install(TARGETS wav)
