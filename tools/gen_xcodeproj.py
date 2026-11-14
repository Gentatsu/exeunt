#!/usr/bin/env python3
"""Writes Exeunt.xcodeproj (macOS app + unit tests, folder-synchronised groups); run from the repo root."""

import os

APP = "Exeunt"
BUNDLE = "uk.co.onibaku.exeunt"

# Fixed ids so regenerating gives no diff.
ids = {}


def i(key):
    return ids.setdefault(key, f"{0xB0000000 + len(ids):08X}0000000000000000")


COMMON = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "CURRENT_PROJECT_VERSION": "1",
    "DEVELOPMENT_TEAM": "39NS894P5C",
    "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
    "MACOSX_DEPLOYMENT_TARGET": "13.0",
    "MARKETING_VERSION": "1.1.0",
    "SDKROOT": "macosx",
    "SWIFT_VERSION": "5.0",
}
DEBUG = {
    "DEBUG_INFORMATION_FORMAT": "dwarf",
    "ENABLE_TESTABILITY": "YES",
    "GCC_OPTIMIZATION_LEVEL": "0",
    "ONLY_ACTIVE_ARCH": "YES",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
    "SWIFT_OPTIMIZATION_LEVEL": '"-Onone"',
}
RELEASE = {
    "DEBUG_INFORMATION_FORMAT": '"dwarf-with-dsym"',
    "SWIFT_COMPILATION_MODE": "wholemodule",
}
TARGETS = [
    (
        APP,
        "com.apple.product-type.application",
        "app",
        {
            "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
            "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
            "CODE_SIGN_STYLE": "Automatic",
            "COMBINE_HIDPI_IMAGES": "YES",
            "ENABLE_HARDENED_RUNTIME": "YES",
            "GENERATE_INFOPLIST_FILE": "YES",
            "INFOPLIST_KEY_CFBundleDisplayName": APP,
            "INFOPLIST_KEY_LSApplicationCategoryType": '"public.app-category.utilities"',
            "INFOPLIST_KEY_LSUIElement": "YES",
            "INFOPLIST_KEY_NSHumanReadableCopyright": '"© 2026 Onibaku Ltd"',
            "LD_RUNPATH_SEARCH_PATHS": '"$(inherited) @executable_path/../Frameworks"',
            "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE,
            "PRODUCT_NAME": '"$(TARGET_NAME)"',
        },
    ),
    (
        APP + "Tests",
        "com.apple.product-type.bundle.unit-test",
        "xctest",
        {
            "BUNDLE_LOADER": '"$(TEST_HOST)"',
            "CODE_SIGN_STYLE": "Automatic",
            "GENERATE_INFOPLIST_FILE": "YES",
            "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE + ".tests",
            "PRODUCT_NAME": '"$(TARGET_NAME)"',
            "TEST_HOST": f'"$(BUILT_PRODUCTS_DIR)/{APP}.app/Contents/MacOS/{APP}"',
        },
    ),
]


def block(settings):
    return "".join(f"\t\t\t\t{k} = {v};\n" for k, v in sorted(settings.items()))


def config(owner, name, settings):
    return (
        f"\t\t{i(owner + name)} = {{\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {{\n{block(settings)}"
        f"\t\t\t}};\n\t\t\tname = {name};\n\t\t}};\n"
    )


def config_list(owner):
    return (
        f"\t\t{i(owner + 'List')} = {{\n\t\t\tisa = XCConfigurationList;\n\t\t\tbuildConfigurations = ("
        f"{i(owner + 'Debug')}, {i(owner + 'Release')}, );\n\t\t\tdefaultConfigurationIsVisible = 0;\n"
        "\t\t\tdefaultConfigurationName = Release;\n\t\t};\n"
    )


objects = ""
for name, ptype, ext, settings in TARGETS:
    deps = f"{i(APP + 'Dep')}, " if name != APP else ""
    objects += (
        f"\t\t{i(name)} = {{\n\t\t\tisa = PBXNativeTarget;\n"
        f"\t\t\tbuildConfigurationList = {i(name + 'List')};\n"
        f"\t\t\tbuildPhases = ({i(name + 'Src')}, {i(name + 'Fwk')}, {i(name + 'Res')}, );\n"
        f"\t\t\tbuildRules = ();\n\t\t\tdependencies = ({deps});\n"
        f"\t\t\tfileSystemSynchronizedGroups = ({i(name + 'Dir')}, );\n"
        f"\t\t\tname = {name};\n\t\t\tproductName = {name};\n\t\t\tproductReference = {i(name + 'Out')};\n"
        f'\t\t\tproductType = "{ptype}";\n\t\t}};\n'
        f'\t\t{i(name + "Dir")} = {{isa = PBXFileSystemSynchronizedRootGroup; path = {name}; sourceTree = "<group>"; }};\n'
        f"\t\t{i(name + 'Out')} = {{isa = PBXFileReference; explicitFileType = wrapper.{'application' if ext == 'app' else 'cfbundle'}; "
        f"includeInIndex = 0; path = {name}.{ext}; sourceTree = BUILT_PRODUCTS_DIR; }};\n"
    )
    for phase, isa in (
        ("Src", "PBXSourcesBuildPhase"),
        ("Fwk", "PBXFrameworksBuildPhase"),
        ("Res", "PBXResourcesBuildPhase"),
    ):
        objects += (
            f"\t\t{i(name + phase)} = {{isa = {isa}; buildActionMask = 2147483647; files = (); "
            "runOnlyForDeploymentPostprocessing = 0; };\n"
        )
    objects += (
        config(name, "Debug", settings)
        + config(name, "Release", settings)
        + config_list(name)
    )

objects += (
    f"\t\t{i(APP + 'Dep')} = {{isa = PBXTargetDependency; target = {i(APP)}; targetProxy = {i(APP + 'Proxy')}; }};\n"
    f"\t\t{i(APP + 'Proxy')} = {{isa = PBXContainerItemProxy; containerPortal = {i('Project')}; proxyType = 1; "
    f"remoteGlobalIDString = {i(APP)}; remoteInfo = {APP}; }};\n"
    f"\t\t{i('Products')} = {{isa = PBXGroup; children = ({''.join(i(t[0] + 'Out') + ', ' for t in TARGETS)}); "
    'name = Products; sourceTree = "<group>"; };\n'
    f"\t\t{i('Root')} = {{isa = PBXGroup; children = ({''.join(i(t[0] + 'Dir') + ', ' for t in TARGETS)}{i('Products')}, ); "
    'sourceTree = "<group>"; };\n'
    f"\t\t{i('Project')} = {{\n\t\t\tisa = PBXProject;\n\t\t\tattributes = {{ LastUpgradeCheck = 2640; }};\n"
    f'\t\t\tbuildConfigurationList = {i("ProjectList")};\n\t\t\tcompatibilityVersion = "Xcode 16.0";\n'
    "\t\t\tdevelopmentRegion = en;\n\t\t\thasScannedForEncodings = 0;\n\t\t\tknownRegions = (en, Base, de, fr, es, it, \"pt-BR\", ja, ko, \"zh-Hans\", nl, pl, tr, );\n"
    f'\t\t\tmainGroup = {i("Root")};\n\t\t\tproductRefGroup = {i("Products")};\n\t\t\tprojectDirPath = "";\n'
    f'\t\t\tprojectRoot = "";\n\t\t\ttargets = ({"".join(i(t[0]) + ", " for t in TARGETS)});\n\t\t}};\n'
)
objects += (
    config("Project", "Debug", COMMON | DEBUG)
    + config("Project", "Release", COMMON | RELEASE)
    + config_list("Project")
)

project = f"{APP}.xcodeproj"
os.makedirs(f"{project}/xcshareddata/xcschemes", exist_ok=True)
with open(f"{project}/project.pbxproj", "w") as f:
    f.write(
        "// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 77;\n\tobjects = {\n"
        f"{objects}\t}};\n\trootObject = {i('Project')};\n}}\n"
    )


def ref(name, ext):
    return (
        f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{i(name)}" '
        f'BuildableName="{name}.{ext}" BlueprintName="{name}" ReferencedContainer="container:{project}"/>'
    )


app = ref(APP, "app")
tests = f'<TestableReference skipped="NO" parallelizable="NO">{ref(TARGETS[1][0], "xctest")}</TestableReference>\n'
with open(f"{project}/xcshareddata/xcschemes/{APP}.xcscheme", "w") as f:
    f.write(f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2640" version="1.7">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
<BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app}</BuildActionEntry></BuildActionEntries>
</BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES">
<Testables>
{tests}</Testables>
</TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="NO">
<BuildableProductRunnable runnableDebuggingMode="0">{app}</BuildableProductRunnable>
</LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES">
<BuildableProductRunnable runnableDebuggingMode="0">{app}</BuildableProductRunnable>
</ProfileAction>
<AnalyzeAction buildConfiguration="Debug"></AnalyzeAction>
<ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"></ArchiveAction>
</Scheme>
""")
