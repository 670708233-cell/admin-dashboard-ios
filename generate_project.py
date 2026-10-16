#!/usr/bin/env python3
"""
Generate a complete Xcode project.pbxproj for the AdminDashboard iOS app.
This avoids the need for XcodeGen and gives full control over the project structure.
"""
import os
import hashlib
import uuid

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SRC_DIR = os.path.join(BASE_DIR, "AdminDashboard")

# Collect all Swift files
swift_files = []
for root, dirs, files in os.walk(SRC_DIR):
    for f in sorted(files):
        if f.endswith(".swift"):
            full = os.path.join(root, f)
            rel = os.path.relpath(full, BASE_DIR).replace("\\", "/")
            swift_files.append(rel)

print(f"Found {len(swift_files)} Swift files:")
for sf in swift_files:
    print(f"  {sf}")

# Generate unique 24-char hex IDs
def gen_id(seed):
    h = hashlib.md5(seed.encode()).hexdigest()
    return h[:24].upper()

# Build PBXFileReference and PBXBuildFile entries
file_refs = {}
build_files = {}
groups = {}  # group path -> (group_id, children_ids)

# Create group structure
def ensure_group(path_parts):
    if not path_parts:
        return None
    key = "/".join(path_parts)
    if key in groups:
        return groups[key][0]
    
    gid = gen_id("group:" + key)
    children = []
    groups[key] = (gid, children)
    return gid

# Root group
root_gid = gen_id("group:ROOT")
groups[""] = (root_gid, [])

# Process files
for sf in swift_files:
    # File reference
    fid = gen_id("file:" + sf)
    file_refs[sf] = fid
    
    # Build file reference
    bid = gen_id("build:" + sf)
    build_files[sf] = bid
    
    # Group path
    parts = sf.split("/")
    # Ensure parent group exists
    parent_parts = parts[:-1]
    parent_gid = ensure_group(parent_parts) if parent_parts else root_gid
    
    # Add to parent group's children
    parent_key = "/".join(parent_parts)
    if parent_key in groups:
        groups[parent_key][1].append(fid)
    else:
        groups[""][1].append(fid)

# Generate project.pbxproj content
lines = []
lines.append("// !$*UTF8*$!")
lines.append("{")
lines.append("\tarchiveVersion = 1;")
lines.append("\tclasses = {")
lines.append("\t};")
lines.append("\tobjectVersion = 77;")
lines.append("\tobjects = {")
lines.append("")

# PBXFileReference section
lines.append("/* Begin PBXFileReference section */")
app_fid = gen_id("file:AdminDashboard.app")
lines.append(f"\t\t{app_fid} /* AdminDashboard.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = AdminDashboard.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
for sf, fid in sorted(file_refs.items()):
    lines.append(f"\t\t{fid} /* {os.path.basename(sf)} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {os.path.basename(sf)}; sourceTree = \"<group>\"; }};")
lines.append("/* End PBXFileReference section */")
lines.append("")

# PBXBuildFile section
lines.append("/* Begin PBXBuildFile section */")
for sf, bid in sorted(build_files.items()):
    fid = file_refs[sf]
    lines.append(f"\t\t{bid} /* {os.path.basename(sf)} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {os.path.basename(sf)} */; }};")
lines.append("/* End PBXBuildFile section */")
lines.append("")

# PBXFrameworksBuildPhase section
fw_bid = gen_id("fw:phase")
lines.append("/* Begin PBXFrameworksBuildPhase section */")
lines.append(f"\t\t{fw_bid} /* Frameworks */ = {{")
lines.append("\t\t\tisa = PBXFrameworksBuildPhase;")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append("/* End PBXFrameworksBuildPhase section */")
lines.append("")

# PBXGroup section
lines.append("/* Begin PBXGroup section */")
lines.append(f"\t\t{root_gid} = {{")
lines.append("\t\t\tisa = PBXGroup;")
lines.append("\t\t\tchildren = (")
# Add top-level groups (AdminDashboard dir)
for key, (gid, children) in sorted(groups.items()):
    if key and "/" not in key:
        lines.append(f"\t\t\t\t{gid} /* {key} */,")
lines.append(f"\t\t\t\t{app_fid} /* AdminDashboard.app */,")
lines.append("\t\t\t);")
lines.append("\t\t\tsourceTree = \"<group>\";")
lines.append("\t\t};")

# Add subgroups
for key, (gid, children) in sorted(groups.items()):
    if not key:
        continue
    dirname = key.split("/")[-1]
    lines.append(f"\t\t{gid} /* {dirname} */ = {{")
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    for child in children:
        # Find if this child is a file or group
        is_file = child in file_refs.values()
        if is_file:
            # Find filename
            fname = [k for k, v in file_refs.items() if v == child][0]
            lines.append(f"\t\t\t\t{child} /* {os.path.basename(fname)} */,")
        else:
            # It's a group - find its name
            gname = [k for k, (g, _) in groups.items() if g == child][0]
            lines.append(f"\t\t\t\t{child} /* {gname.split('/')[-1]} */,")
    lines.append("\t\t\t);")
    lines.append(f"\t\t\tpath = {dirname};")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")
lines.append("/* End PBXGroup section */")
lines.append("")

# PBXNativeTarget section
target_id = gen_id("target:AdminDashboard")
src_phase_id = gen_id("src:phase")
res_phase_id = gen_id("res:phase")
lines.append("/* Begin PBXNativeTarget section */")
lines.append(f"\t\t{target_id} /* AdminDashboard */ = {{")
lines.append("\t\t\tisa = PBXNativeTarget;")
lines.append(f"\t\t\tbuildConfigurationList = {gen_id('bcl:target')} /* Build configuration list for PBXNativeTarget \"AdminDashboard\" */;")
lines.append("\t\t\tbuildPhases = (")
lines.append(f"\t\t\t\t{src_phase_id} /* Sources */,")
lines.append(f"\t\t\t\t{fw_bid} /* Frameworks */,")
lines.append(f"\t\t\t\t{res_phase_id} /* Resources */,")
lines.append("\t\t\t);")
lines.append("\t\t\tbuildRules = (")
lines.append("\t\t\t);")
lines.append("\t\t\tdependencies = (")
lines.append("\t\t\t);")
lines.append("\t\t\tname = AdminDashboard;")
lines.append("\t\t\tproductName = AdminDashboard;")
lines.append(f"\t\t\tproductReference = {app_fid} /* AdminDashboard.app */;")
lines.append("\t\t\tproductType = \"com.apple.product-type.application\";")
lines.append("\t\t};")
lines.append("/* End PBXNativeTarget section */")
lines.append("")

# PBXProject section
proj_id = gen_id("proj:AdminDashboard")
lines.append("/* Begin PBXProject section */")
lines.append(f"\t\t{proj_id} /* Project object */ = {{")
lines.append("\t\t\tisa = PBXProject;")
lines.append("\t\t\tattributes = {")
lines.append("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
lines.append("\t\t\t\tLastSwiftUpdateCheck = 1500;")
lines.append("\t\t\t\tLastUpgradeCheck = 1500;")
lines.append("\t\t\t\tTargetAttributes = {")
lines.append(f"\t\t\t\t\t{target_id} = {{")
lines.append("\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;")
lines.append("\t\t\t\t\t};")
lines.append("\t\t\t\t};")
lines.append("\t\t\t};")
lines.append(f"\t\t\tbuildConfigurationList = {gen_id('bcl:project')} /* Build configuration list for PBXProject \"AdminDashboard\" */;")
lines.append("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
lines.append("\t\t\tdevelopmentRegion = en;")
lines.append("\t\t\thasScannedForEncodings = 0;")
lines.append("\t\t\tknownRegions = (")
lines.append("\t\t\t\ten,")
lines.append("\t\t\t\tBase,")
lines.append("\t\t\t);")
lines.append(f"\t\t\tmainGroup = {root_gid};")
lines.append(f"\t\t\tproductRefGroup = {root_gid};")
lines.append("\t\t\tprojectDirPath = \"\";")
lines.append("\t\t\tprojectRoot = \"\";")
lines.append("\t\t\ttargets = (")
lines.append(f"\t\t\t\t{target_id} /* AdminDashboard */,")
lines.append("\t\t\t);")
lines.append("\t\t};")
lines.append("/* End PBXProject section */")
lines.append("")

# PBXResourcesBuildPhase section
lines.append("/* Begin PBXResourcesBuildPhase section */")
lines.append(f"\t\t{res_phase_id} /* Resources */ = {{")
lines.append("\t\t\tisa = PBXResourcesBuildPhase;")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append("/* End PBXResourcesBuildPhase section */")
lines.append("")

# PBXSourcesBuildPhase section
lines.append("/* Begin PBXSourcesBuildPhase section */")
lines.append(f"\t\t{src_phase_id} /* Sources */ = {{")
lines.append("\t\t\tisa = PBXSourcesBuildPhase;")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
for sf, bid in sorted(build_files.items()):
    lines.append(f"\t\t\t\t{bid} /* {os.path.basename(sf)} in Sources */,")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append("/* End PBXSourcesBuildPhase section */")
lines.append("")

# XCBuildConfiguration sections
def build_config(config_id, name, is_target, is_debug):
    lines.append(f"\t\t{config_id} /* {name} */ = {{")
    lines.append("\t\t\tisa = XCBuildConfiguration;")
    lines.append("\t\t\tbuildSettings = {")
    if not is_target:
        lines.append("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
        lines.append("\t\t\t\tCLANG_ANALYZER_NONNULL = YES;")
        lines.append("\t\t\t\tCLANG_ENABLE_MODULES = YES;")
        lines.append("\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;")
        lines.append("\t\t\t\tCOPY_PHASE_STRIP = NO;")
        lines.append("\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;")
        lines.append("\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu11;")
        lines.append("\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;")
        lines.append("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;")
        lines.append("\t\t\t\tMTL_FAST_MATH = YES;")
        lines.append("\t\t\t\tSDKROOT = iphoneos;")
        lines.append("\t\t\t\tSWIFT_VERSION = 5.0;")
        if is_debug:
            lines.append("\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;")
            lines.append("\t\t\t\tENABLE_TESTABILITY = YES;")
            lines.append("\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;")
            lines.append("\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;")
            lines.append("\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (\"DEBUG=1\", \"$(inherited)\", );")
            lines.append("\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;")
            lines.append("\t\t\t\tONLY_ACTIVE_ARCH = YES;")
            lines.append("\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;")
            lines.append("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";")
        else:
            lines.append("\t\t\t\tDEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";")
            lines.append("\t\t\t\tENABLE_NS_ASSERTIONS = NO;")
            lines.append("\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;")
            lines.append("\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;")
            lines.append("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-O\";")
    else:
        lines.append("\t\t\t\tCODE_SIGN_STYLE = Manual;")
        lines.append("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
        lines.append("\t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = NO;")
        lines.append("\t\t\t\tGENERATE_INFOPLIST_FILE = NO;")
        lines.append("\t\t\t\tINFOPLIST_FILE = AdminDashboard/Info.plist;")
        lines.append("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (\"$(inherited)\", \"@executable_path/Frameworks\", );")
        lines.append("\t\t\t\tMARKETING_VERSION = 1.0;")
        lines.append("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.doushujun.admin;")
        lines.append("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
        lines.append("\t\t\t\tSWIFT_VERSION = 5.0;")
        lines.append("\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";")
    lines.append("\t\t\t};")
    lines.append(f"\t\t\tname = {name};")
    lines.append("\t\t};")

# Project-level configs
build_config(gen_id("pcfg:debug"), "Debug", False, True)
build_config(gen_id("pcfg:release"), "Release", False, False)

# Target-level configs
build_config(gen_id("tcfg:debug"), "Debug", True, True)
build_config(gen_id("tcfg:release"), "Release", True, False)
lines.append("")

# XCConfigurationList sections
lines.append("/* Begin XCConfigurationList section */")
bcl_target = gen_id("bcl:target")
bcl_project = gen_id("bcl:project")
lines.append(f"\t\t{bcl_target} /* Build configuration list for PBXNativeTarget \"AdminDashboard\" */ = {{")
lines.append("\t\t\tisa = XCConfigurationList;")
lines.append("\t\t\tbuildConfigurations = (")
lines.append(f"\t\t\t\t{gen_id('tcfg:debug')} /* Debug */,")
lines.append(f"\t\t\t\t{gen_id('tcfg:release')} /* Release */,")
lines.append("\t\t\t);")
lines.append("\t\t\tdefaultConfigurationIsVisible = 0;")
lines.append("\t\t\tdefaultConfigurationName = Release;")
lines.append("\t\t};")
lines.append(f"\t\t{bcl_project} /* Build configuration list for PBXProject \"AdminDashboard\" */ = {{")
lines.append("\t\t\tisa = XCConfigurationList;")
lines.append("\t\t\tbuildConfigurations = (")
lines.append(f"\t\t\t\t{gen_id('pcfg:debug')} /* Debug */,")
lines.append(f"\t\t\t\t{gen_id('pcfg:release')} /* Release */,")
lines.append("\t\t\t);")
lines.append("\t\t\tdefaultConfigurationIsVisible = 0;")
lines.append("\t\t\tdefaultConfigurationName = Release;")
lines.append("\t\t};")
lines.append("/* End XCConfigurationList section */")
lines.append("")

lines.append("\t};")
lines.append(f"\trootObject = {proj_id} /* Project object */;")
lines.append("}")

# Write to file
xcodeproj_dir = os.path.join(BASE_DIR, "AdminDashboard.xcodeproj")
os.makedirs(xcodeproj_dir, exist_ok=True)
out_path = os.path.join(xcodeproj_dir, "project.pbxproj")
with open(out_path, "w", encoding="utf-8") as f:
    f.write("\n".join(lines))
print(f"\nGenerated: {out_path}")
print(f"Total files: {len(swift_files)}")
