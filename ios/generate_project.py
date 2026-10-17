#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parent
APP_DIR = ROOT / "TiXing"
TEST_DIR = ROOT / "TiXingTests"

source_files = sorted(str(path.relative_to(APP_DIR)) for path in APP_DIR.rglob("*.swift"))
test_files = sorted(str(path.relative_to(TEST_DIR)) for path in TEST_DIR.rglob("*.swift"))

counter = 0
def ident(prefix):
    global counter
    counter += 1
    return f"{counter:024X}"

ids = {}
source_build = {}
test_build = {}
resource_build = {}

project_id = ident("P")
main_group = ident("M")
products_group = ident("G")
config_list_project = ident("L")
config_debug_project = ident("C")
config_release_project = ident("D")
app_target = ident("T")
test_target = ident("U")
app_config_list = ident("A")
test_config_list = ident("B")
app_debug = ident("E")
app_release = ident("F")
test_debug = ident("H")
test_release = ident("I")
app_product = ident("R")
test_product = ident("S")
sources_phase = ident("V")
frameworks_phase = ident("W")
resources_phase = ident("X")
test_sources_phase = ident("Y")
test_frameworks_phase = ident("Z")
test_resources_phase = ident("N")
script_phase = ident("O")
dependency = ident("K")
container_proxy = ident("Q")
app_group = ident("J")
test_group = ident("AA")

for path in source_files:
    file_id = ident("F")
    build_id = ident("B")
    ids[file_id] = path
    source_build[build_id] = file_id

for path in test_files:
    file_id = ident("F")
    build_id = ident("B")
    ids[file_id] = path
    test_build[build_id] = file_id

for path in ["Resources/Assets.xcassets"]:
    file_id = ident("F")
    build_id = ident("B")
    ids[file_id] = path
    resource_build[build_id] = file_id

objects = []

def object_block(isa, object_id, values):
    lines = [f"\t\t{object_id} /* {isa} */ = {{", f"\t\t\tisa = {isa};"]
    for key, value in values:
        lines.append(f"\t\t\t{key} = {value};")
    lines.append("\t\t};")
    objects.append("\n".join(lines))

for build_id, file_id in source_build.items():
    object_block("PBXBuildFile", build_id, [("fileRef", f"{file_id} /* {ids[file_id]} */")])
for build_id, file_id in test_build.items():
    object_block("PBXBuildFile", build_id, [("fileRef", f"{file_id} /* {ids[file_id]} */")])
for build_id, file_id in resource_build.items():
    object_block("PBXBuildFile", build_id, [("fileRef", f"{file_id} /* {ids[file_id]} */")])

for file_id, path in ids.items():
    if path.endswith(".swift"):
        object_block("PBXFileReference", file_id, [
            ("lastKnownFileType", "sourcecode.swift"),
            ("path", f'"{path}"'),
            ("sourceTree", '"<group>"'),
        ])

for file_id in resource_build.values():
    object_block("PBXFileReference", file_id, [
        ("lastKnownFileType", "folder.assetcatalog"),
        ("path", f'"{ids[file_id]}"'),
        ("sourceTree", '"<group>"'),
    ])

object_block("PBXFileReference", app_product, [
    ("explicitFileType", "wrapper.application"),
    ("includeInIndex", "0"),
    ("path", "TiXing.app"),
    ("sourceTree", "BUILT_PRODUCTS_DIR"),
])
object_block("PBXFileReference", test_product, [
    ("explicitFileType", "wrapper.cfbundle"),
    ("includeInIndex", "0"),
    ("path", "TiXingTests.xctest"),
    ("sourceTree", "BUILT_PRODUCTS_DIR"),
])

object_block("PBXGroup", app_group, [
    ("children", "(" + ", ".join(f"{value} /* {ids[value]} */" for value in source_build.values()) +
                ", " + ", ".join(f"{file_id} /* {ids[file_id]} */" for file_id in resource_build.values()) + ",)"),
    ("path", "TiXing"),
    ("sourceTree", '"<group>"'),
])
object_block("PBXGroup", test_group, [
    ("children", "(" + ", ".join(f"{file_id} /* {ids[file_id]} */" for file_id in test_build.values()) + ",)"),
    ("path", "TiXingTests"),
    ("sourceTree", '"<group>"'),
])
object_block("PBXGroup", products_group, [
    ("children", f"({app_product} /* TiXing.app */, {test_product} /* TiXingTests.xctest */,)"),
    ("name", "Products"),
    ("sourceTree", '"<group>"'),
])
object_block("PBXGroup", main_group, [
    ("children", f"({app_group} /* TiXing */, {test_group} /* TiXingTests */, {products_group} /* Products */,)"),
    ("sourceTree", '"<group>"'),
])

object_block("PBXNativeTarget", app_target, [
    ("buildConfigurationList", f"{app_config_list} /* Build configuration list for PBXNativeTarget \"TiXing\" */"),
    ("buildPhases", f"({sources_phase} /* Sources */, {frameworks_phase} /* Frameworks */, {resources_phase} /* Resources */, {script_phase} /* ShellScript */,)"),
    ("buildRules", "()"),
    ("dependencies", "()"),
    ("name", "TiXing"),
    ("productName", "TiXing"),
    ("productReference", f"{app_product} /* TiXing.app */"),
    ("productType", '"com.apple.product-type.application"'),
])
object_block("PBXNativeTarget", test_target, [
    ("buildConfigurationList", f"{test_config_list} /* Build configuration list for PBXNativeTarget \"TiXingTests\" */"),
    ("buildPhases", f"({test_sources_phase} /* Sources */, {test_frameworks_phase} /* Frameworks */, {test_resources_phase} /* Resources */,)"),
    ("buildRules", "()"),
    ("dependencies", f"({dependency} /* PBXTargetDependency */,)"),
    ("name", "TiXingTests"),
    ("productName", "TiXingTests"),
    ("productReference", f"{test_product} /* TiXingTests.xctest */"),
    ("productType", '"com.apple.product-type.bundle.unit-test"'),
])

object_block("PBXProject", project_id, [
    ("attributes", "{ BuildIndependentTargetsInParallel = 1; LastSwiftUpdateCheck = 2700; LastUpgradeCheck = 2700; TargetAttributes = { " +
                   f"{app_target} = {{ CreatedOnToolsVersion = 27.0; }}; {test_target} = {{ CreatedOnToolsVersion = 27.0; TestTargetID = {app_target}; }}; }}; " + "}"),
    ("buildConfigurationList", f"{config_list_project} /* Build configuration list for PBXProject \"TiXing\" */"),
    ("compatibilityVersion", '"Xcode 14.0"'),
    ("developmentRegion", '"zh-CN"'),
    ("hasScannedForEncodings", "0"),
    ("knownRegions", '("zh-CN", en, Base,)'),
    ("mainGroup", f"{main_group} /* Main group */"),
    ("productRefGroup", f"{products_group} /* Products */"),
    ("projectDirPath", '""'),
    ("projectRoot", '""'),
    ("targets", f"({app_target} /* TiXing */, {test_target} /* TiXingTests */,)"),
])

object_block("PBXSourcesBuildPhase", sources_phase, [("files", "(" + ", ".join(f"{key} /* {ids[value]} */" for key, value in source_build.items()) + ",)")])
object_block("PBXSourcesBuildPhase", test_sources_phase, [("files", "(" + ", ".join(f"{key} /* {ids[value]} */" for key, value in test_build.items()) + ",)")])
object_block("PBXFrameworksBuildPhase", frameworks_phase, [("files", "()"), ("runOnlyForDeploymentPostprocessing", "0")])
object_block("PBXFrameworksBuildPhase", test_frameworks_phase, [("files", "()"), ("runOnlyForDeploymentPostprocessing", "0")])
object_block("PBXResourcesBuildPhase", resources_phase, [("files", "(" + ", ".join(f"{key} /* {ids[value]} */" for key, value in resource_build.items()) + ",)"), ("runOnlyForDeploymentPostprocessing", "0")])
object_block("PBXResourcesBuildPhase", test_resources_phase, [("files", "()"), ("runOnlyForDeploymentPostprocessing", "0")])

script = r'if [ -f "${SRCROOT}/TiXing/Resources/apiconfig.json" ]; then\n\tcp "${SRCROOT}/TiXing/Resources/apiconfig.json" "${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/apiconfig.json"\nelse\n\techo "warning: TiXing/Resources/apiconfig.json is not present; AI features will report not configured."\nfi'
object_block("PBXShellScriptBuildPhase", script_phase, [
    ("alwaysOutOfDate", "1"),
    ("buildActionMask", "2147483647"),
    ("files", "()"),
    ("inputPaths", "()"),
    ("outputPaths", "()"),
    ("runOnlyForDeploymentPostprocessing", "0"),
    ("shellPath", "/bin/sh"),
    ("shellScript", '"' + script.replace('"', '\\"') + '"'),
])

object_block("PBXContainerItemProxy", container_proxy, [
    ("containerPortal", f"{project_id} /* Project object */"),
    ("proxyType", "1"),
    ("remoteGlobalIDString", f"{app_target}"),
    ("remoteInfo", "TiXing"),
])
object_block("PBXTargetDependency", dependency, [
    ("target", f"{app_target} /* TiXing */"),
    ("targetProxy", f"{container_proxy} /* PBXContainerItemProxy */"),
])

project_settings = [
    ("ALWAYS_SEARCH_USER_PATHS", "NO"),
    ("CLANG_ENABLE_MODULES", "YES"),
    ("CLANG_ENABLE_OBJC_ARC", "YES"),
    ("COPY_PHASE_STRIP", "NO"),
    ("DEAD_CODE_STRIPPING", "YES"),
    ("ENABLE_STRICT_OBJC_MSGSEND", "YES"),
    ("GCC_C_LANGUAGE_STANDARD", '"gnu17"'),
    ("GCC_NO_COMMON_BLOCKS", "YES"),
    ("IPHONEOS_DEPLOYMENT_TARGET", "17.0"),
    ("SDKROOT", "iphoneos"),
    ("SUPPORTED_PLATFORMS", '"iphoneos iphonesimulator"'),
    ("SWIFT_VERSION", "5.0"),
]
debug_project = project_settings + [("SWIFT_ACTIVE_COMPILATION_CONDITIONS", "DEBUG"), ("SWIFT_OPTIMIZATION_LEVEL", "-Onone")]
release_project = project_settings + [("SWIFT_COMPILATION_MODE", "wholemodule"), ("SWIFT_OPTIMIZATION_LEVEL", "-O"), ("VALIDATE_PRODUCT", "YES")]
object_block("XCBuildConfiguration", config_debug_project, [("buildSettings", "{" + " ".join(f"{k} = {v};" for k, v in debug_project) + "}"), ("name", "Debug")])
object_block("XCBuildConfiguration", config_release_project, [("buildSettings", "{" + " ".join(f"{k} = {v};" for k, v in release_project) + "}"), ("name", "Release")])

app_settings = [
    ("ASSETCATALOG_COMPILER_APPICON_NAME", "AppIcon"),
    ("ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME", "AccentColor"),
    ("CODE_SIGN_STYLE", "Automatic"),
    ("CURRENT_PROJECT_VERSION", "1000003"),
    ("DEVELOPMENT_ASSET_PATHS", '""'),
    ("ENABLE_PREVIEWS", "YES"),
    ("ENABLE_USER_SCRIPT_SANDBOXING", "NO"),
    ("GENERATE_INFOPLIST_FILE", "NO"),
    ("INFOPLIST_FILE", "TiXing/Resources/Info.plist"),
    ("LD_RUNPATH_SEARCH_PATHS", '"$(inherited) @executable_path/Frameworks"'),
    ("MARKETING_VERSION", "1.0.3"),
    ("PRODUCT_BUNDLE_IDENTIFIER", "com.tixing.me.ios"),
    ("PRODUCT_NAME", '"$(TARGET_NAME)"'),
    ("SUPPORTS_MACCATALYST", "NO"),
    ("TARGETED_DEVICE_FAMILY", "1"),
]
app_debug_settings = app_settings + [("ENABLE_TESTABILITY", "YES")]
object_block("XCBuildConfiguration", app_debug, [("buildSettings", "{" + " ".join(f"{k} = {v};" for k, v in app_debug_settings) + "}"), ("name", "Debug")])
object_block("XCBuildConfiguration", app_release, [("buildSettings", "{" + " ".join(f"{k} = {v};" for k, v in app_settings) + "}"), ("name", "Release")])

test_settings = [
    ("CODE_SIGN_STYLE", "Automatic"),
    ("CURRENT_PROJECT_VERSION", "1"),
    ("GENERATE_INFOPLIST_FILE", "YES"),
    ("MARKETING_VERSION", "1.0"),
    ("PRODUCT_BUNDLE_IDENTIFIER", "com.tixing.me.ios.tests"),
    ("PRODUCT_NAME", '"$(TARGET_NAME)"'),
    ("SWIFT_EMIT_LOC_STRINGS", "NO"),
    ("TARGETED_DEVICE_FAMILY", "1"),
    ("TEST_HOST", '"$(BUILT_PRODUCTS_DIR)/TiXing.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/TiXing"'),
    ("BUNDLE_LOADER", '"$(TEST_HOST)"'),
]
object_block("XCBuildConfiguration", test_debug, [("buildSettings", "{" + " ".join(f"{k} = {v};" for k, v in test_settings) + "}"), ("name", "Debug")])
object_block("XCBuildConfiguration", test_release, [("buildSettings", "{" + " ".join(f"{k} = {v};" for k, v in test_settings) + "}"), ("name", "Release")])

object_block("XCConfigurationList", config_list_project, [
    ("buildConfigurations", f"({config_debug_project} /* Debug */, {config_release_project} /* Release */,)"),
    ("defaultConfigurationIsVisible", "0"),
    ("defaultConfigurationName", "Release"),
])
object_block("XCConfigurationList", app_config_list, [
    ("buildConfigurations", f"({app_debug} /* Debug */, {app_release} /* Release */,)"),
    ("defaultConfigurationIsVisible", "0"),
    ("defaultConfigurationName", "Release"),
])
object_block("XCConfigurationList", test_config_list, [
    ("buildConfigurations", f"({test_debug} /* Debug */, {test_release} /* Release */,)"),
    ("defaultConfigurationIsVisible", "0"),
    ("defaultConfigurationName", "Release"),
])

content = "\n".join([
    "// !$*UTF8*$!",
    "{",
    "\tarchiveVersion = 1;",
    "\tobjectVersion = 56;",
    "\tclasses = {",
    "\t};",
    "\tobjects = {",
    "\n\n".join(objects),
    "\t};",
    f"\trootObject = {project_id} /* Project object */;",
    "}",
    "",
])
(ROOT / "TiXing.xcodeproj").mkdir(exist_ok=True)
(ROOT / "TiXing.xcodeproj" / "project.pbxproj").write_text(content)
print(f"Generated TiXing.xcodeproj with {len(source_files)} app sources, {len(test_files)} test sources")
