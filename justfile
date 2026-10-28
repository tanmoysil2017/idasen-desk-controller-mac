set shell := ["bash", "-euo", "pipefail", "-c"]

developer_dir := env("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer")
build_dir := justfile_directory() / "build"
app_bundle := build_dir / "Build/Products/Release/Desk Controller.app"

# Build the complete Release app for Apple Silicon and Intel with local signing.
build:
    rm -rf '{{app_bundle}}'
    env DEVELOPER_DIR="{{developer_dir}}" xcodebuild \
        -project 'Desk Controller.xcodeproj' \
        -scheme 'Desk Controller' \
        -configuration Release \
        -destination 'generic/platform=macOS' \
        -derivedDataPath '{{build_dir}}' \
        ONLY_ACTIVE_ARCH=NO \
        CODE_SIGN_STYLE=Manual \
        CODE_SIGN_IDENTITY=- \
        DEVELOPMENT_TEAM= \
        build
    bash scripts/verify-native.sh '{{app_bundle}}'
    codesign --verify --deep --strict '{{app_bundle}}'

# Build, then replace the installed app; quit Desk Controller before deploying.
deploy applications_dir="/Applications": build
    test -d '{{app_bundle}}'
    mkdir -p '{{applications_dir}}'
    rm -rf '{{applications_dir}}/Desk Controller.app'
    ditto '{{app_bundle}}' '{{applications_dir}}/Desk Controller.app'
