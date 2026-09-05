cmake_minimum_required(VERSION 3.20)
project(OriginalMotivationGenerator LANGUAGES Swift)

set(CMAKE_Swift_LANGUAGE_VERSION 5.0)
set(CMAKE_OSX_DEPLOYMENT_TARGET "15.0" CACHE STRING "Minimum iOS deployment version" FORCE)
set(OMG_BUNDLE_IDENTIFIER "com.kurio.original-motivation-generator" CACHE STRING "App bundle identifier")
set(OMG_DEVELOPMENT_TEAM "" CACHE STRING "Optional Apple Developer Team ID")

set(APP_ROOT "${CMAKE_SOURCE_DIR}/App")
set(APP_SOURCES
    "${APP_ROOT}/OriginalMotivationGeneratorApp.swift"
    "${APP_ROOT}/ContentView.swift"
    "${APP_ROOT}/ArtPage.swift"
    "${APP_ROOT}/OncePressStore.swift"
    "${APP_ROOT}/OncePressView.swift"
    "${APP_ROOT}/LetterView.swift"
    "${APP_ROOT}/AppSoundPlayer.swift"
    "${APP_ROOT}/Sounds/page.mp3"
    "${APP_ROOT}/Sounds/click.wav"
    "${APP_ROOT}/Sounds/send.wav"
    "${APP_ROOT}/Sounds/tick.wav"
    "${APP_ROOT}/Clock25.swift"
    "${APP_ROOT}/ClockView.swift"
    "${APP_ROOT}/ClockSettingsView.swift"
    "${APP_ROOT}/SettingsView.swift"
    "${APP_ROOT}/ThreeFingerSwipe.swift"
    "${APP_ROOT}/KurioPhraseGenerator.swift"
)

set_source_files_properties(
    "${APP_ROOT}/Sounds/page.mp3"
    "${APP_ROOT}/Sounds/click.wav"
    "${APP_ROOT}/Sounds/send.wav"
    "${APP_ROOT}/Sounds/tick.wav"
    PROPERTIES MACOSX_PACKAGE_LOCATION Resources
)
add_executable(OriginalMotivationGenerator ${APP_SOURCES})
target_link_libraries(OriginalMotivationGenerator PRIVATE "-framework SwiftUI" "-framework UIKit" "-framework AVFoundation")

set_target_properties(OriginalMotivationGenerator PROPERTIES
    MACOSX_BUNDLE TRUE
    OUTPUT_NAME "原始动机生成器"
    XCODE_GENERATE_SCHEME TRUE
    MACOSX_BUNDLE_INFO_PLIST "${APP_ROOT}/Info.plist"
    XCODE_ATTRIBUTE_INFOPLIST_FILE "${APP_ROOT}/Info.plist"
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "${OMG_BUNDLE_IDENTIFIER}"
    XCODE_ATTRIBUTE_PRODUCT_NAME "原始动机生成器"
    XCODE_ATTRIBUTE_MARKETING_VERSION "1.0.0"
    XCODE_ATTRIBUTE_CURRENT_PROJECT_VERSION "1"
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "15.0"
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
    XCODE_ATTRIBUTE_SDKROOT "iphoneos"
    XCODE_ATTRIBUTE_SUPPORTED_PLATFORMS "iphoneos iphonesimulator"
    XCODE_ATTRIBUTE_SUPPORTS_MACCATALYST "NO"
    XCODE_ATTRIBUTE_CODE_SIGN_STYLE "Automatic"
    XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "YES"
    XCODE_ATTRIBUTE_DEVELOPMENT_TEAM "${OMG_DEVELOPMENT_TEAM}"
    XCODE_ATTRIBUTE_LIBRARY_SEARCH_PATHS "$(TOOLCHAIN_DIR)/usr/lib/swift/$(PLATFORM_NAME) $(inherited)"
    SWIFT_VERSION 5.0
)

set(CMAKE_XCODE_ATTRIBUTE_SDKROOT "iphoneos")
set(CMAKE_XCODE_ATTRIBUTE_SUPPORTED_PLATFORMS "iphoneos iphonesimulator")
set(CMAKE_XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2")
