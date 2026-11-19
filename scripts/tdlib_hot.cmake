# tdlib_hot.cmake - compile TDLib's hot libraries for speed, the rest for size.
#
# Passed by build_tdlib_dylib.sh as CMAKE_PROJECT_INCLUDE, so the submodule
# stays untouched. The whole dylib at -Oz keeps armv7 __TEXT under the 16 MB
# Thumb branch limit, but on the A4's single core TDLib's own work (the actor
# scheduler, JSON for every update, the connection, sqlite) shares the CPU with
# the chat scroll. These targets are ~3.7 MB of the ~16 MB of code; tdcore,
# the rest, stays at -Oz. Under ThinLTO the level travels with each function,
# so the split holds through link time.
#
# TG_HOT_OPT is the level for the hot targets (-O2 by default).
if(NOT DEFINED TG_HOT_OPT)
  set(TG_HOT_OPT -O2)
endif()

function(tg_tdlib_hot_targets)
  foreach(target tdutils tdactor tdnet tddb tdsqlite tdmtproto tdjson_private tdapi tdclient)
    if(TARGET ${target})
      get_target_property(type ${target} TYPE)
      if(NOT type STREQUAL "INTERFACE_LIBRARY")
        target_compile_options(${target} PRIVATE ${TG_HOT_OPT})
      endif()
    endif()
  endforeach()
endfunction()

# project() runs this file before the targets exist; run the function once the
# top-level CMakeLists (and every add_subdirectory in it) is done.
get_property(tg_hot_deferred GLOBAL PROPERTY TG_TDLIB_HOT_DEFERRED)
if(NOT tg_hot_deferred)
  set_property(GLOBAL PROPERTY TG_TDLIB_HOT_DEFERRED TRUE)
  cmake_language(DEFER DIRECTORY ${CMAKE_SOURCE_DIR} CALL tg_tdlib_hot_targets)
endif()
