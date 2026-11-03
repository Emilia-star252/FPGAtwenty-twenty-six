# hmi.pro -- power monitor HMI (1024x600, Qt Widgets + linuxfb on the board)
QT       += core gui network widgets
CONFIG   += c++11
TARGET    = hmi
TEMPLATE  = app

SOURCES += main.cpp \
           hmi.cpp \
           touchinput.cpp

HEADERS += hmi.h \
           protocol.h \
           touchinput.h

# board build: no desktop deps, keep it small
DEFINES += QT_DEPRECATED_WARNINGS
