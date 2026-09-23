# Purpose: the shipped libraries' native halves as one SWI-Prolog package, so a
#   SWI build that links foreign code statically (the WebAssembly one) carries
#   each half as an extension its library activates by name.
# Assumes: tools/wasm-host/build.sh staged this file as packages/metta and,
#   beside it under lib/<library>/, the support/ and vendor/ directories of
#   every library that carries support/static.cmake, as the library holds them.
# Guarantees: every staged support/static.cmake is included once, in path
#   order, so the set of linked halves is exactly the libraries carrying that
#   file and each library describes its own half; a staging with none stops
#   the configure rather than building a host with no library halves.
cmake_minimum_required(VERSION 3.10)
project(swipl-metta C CXX)

include("../cmake/PrologPackage.cmake")

file(GLOB fragments LIST_DIRECTORIES false
     "${CMAKE_CURRENT_SOURCE_DIR}/lib/*/support/static.cmake")
list(SORT fragments)
if(NOT fragments)
  message(FATAL_ERROR
          "packages/metta holds no lib/*/support/static.cmake; "
          "tools/wasm-host/build.sh stages them from the library pack")
endif()
foreach(fragment ${fragments})
  include(${fragment})
endforeach()
