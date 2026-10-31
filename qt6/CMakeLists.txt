cmake_minimum_required(VERSION 3.16)
project(qt6-package NONE)

# Package the finished Qt install tree (keeps symlinks and permissions)
install(DIRECTORY "${QT_PREFIX}/" DESTINATION . USE_SOURCE_PERMISSIONS)

# Ship the Qt license texts if they exist in the source tree
if(EXISTS "${QT_SRC}/LICENSES")
	install(DIRECTORY "${QT_SRC}/LICENSES/" DESTINATION share/licenses/qt6)
endif()

set(CPACK_GENERATOR "STGZ")
set(CPACK_PACKAGE_NAME "qt6")
set(CPACK_PACKAGE_VERSION "${QT_VERSION}")
set(CPACK_PACKAGE_FILE_NAME "qt6-${QT_VERSION}-linux-${QT_ARCH}")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Qt ${QT_VERSION} (qtbase, qtserialport, qtwebsockets)")
set(CPACK_PACKAGE_DIRECTORY "/out")
include(CPack)