find_package(CGAL REQUIRED)
find_package(GMP REQUIRED)
find_package(MPI REQUIRED)

find_package(dune-common REQUIRED)
find_package(dune-istl REQUIRED)
find_package(dune-foamgrid REQUIRED)

find_package(opm-grid REQUIRED)
find_package(opm-simulators REQUIRED)
find_package(opm-upscaling REQUIRED)

if(NOT TARGET opmflowgeomechanics)
  find_package(SuiteSparse COMPONENTS UMFPACK)
  find_package(PETSc)
  find_package(SuperLU)
endif()
