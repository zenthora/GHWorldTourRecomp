# Moves the codegen manifest's timestamp one second before the codegen stamp.
#
# The codegen stamps the manifest's sdk_version (WriteSdkVersionStamp) after writing
# codegen.build.stamp, so the manifest ends up newer than the stamp and Ninja reruns the
# codegen on every build. The stamp must keep its exact timestamp: the deps log records it.
# Moving the manifest back makes the stamp the newest input again.
if(NOT DEFINED MANIFEST OR NOT DEFINED STAMP)
    message(FATAL_ERROR "refresh_codegen_stamp.cmake: MANIFEST and STAMP are required")
endif()
if(NOT EXISTS "${STAMP}" OR NOT EXISTS "${MANIFEST}")
    return()
endif()

if(WIN32)
    set(ENV{GHWT_MANIFEST} "${MANIFEST}")
    set(ENV{GHWT_STAMP} "${STAMP}")
    execute_process(
        COMMAND powershell -NoProfile -NonInteractive -Command
                "$ErrorActionPreference='Stop'; $m=Get-Item -LiteralPath $env:GHWT_MANIFEST; $s=Get-Item -LiteralPath $env:GHWT_STAMP; $m.LastWriteTimeUtc=$s.LastWriteTimeUtc.AddSeconds(-1)"
        RESULT_VARIABLE result)
else()
    execute_process(
        COMMAND sh -c "touch -d @$(( $(stat -c %Y \"$1\") - 1 )) \"$2\"" _ "${STAMP}" "${MANIFEST}"
        RESULT_VARIABLE result)
endif()

if(NOT result EQUAL 0)
    message(FATAL_ERROR "refresh_codegen_stamp.cmake: could not refresh the manifest timestamp (${result})")
endif()
