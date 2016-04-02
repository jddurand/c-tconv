MACRO (FINDVACOPY)
  FOREACH (KEYWORD "va_copy" "_va_copy" "__va_copy")
    MESSAGE(STATUS "-- Looking for ${KEYWORD}")
    TRY_COMPILE (C_HAS_${KEYWORD} ${CMAKE_CURRENT_BINARY_DIR}
      ${CMAKE_CURRENT_SOURCE_DIR}/cmake/va_copy.c
      COMPILE_DEFINITIONS "-DC_VA_COPY=${KEYWORD}")
    IF (C_HAS_${KEYWORD})
      MESSAGE(STATUS "-- Looking for ${KEYWORD} - found")
      SET (C_VA_COPY ${KEYWORD})
      BREAK ()
    ENDIF ()
  ENDFOREACH ()
ENDMACRO ()
FINDVACOPY ()
