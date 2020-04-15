import sys
import os
import glob
import tempfile
import re
import filecmp
import subprocess


def get_file_list(dir):
    result_files = []
    result_dirs = []
    for root, dirs, files in os.walk(dir, topdown=False):
        for name in files:
            result_files.append(os.path.relpath(os.path.join(root, name), dir))
        for name in dirs:
            result_dirs.append(os.path.relpath(os.path.join(root, name), dir))
    return set(result_dirs), set(result_files)


def remove_codesign_dirs(dirs):
    result = set()
    for dir in dirs:
        if dir == '_CodeSignature':
            continue
        if re.match('PlugIns/.*\\.appex/SC_Info', dir):
            continue
        if re.match('Frameworks/.*\\.framework/SC_Info', dir):
            continue
        result.add(dir)
    return result


def remove_codesign_files(files):
    result = set()
    for f in files:
        if f == 'Contents/embedded.provisionprofile':
            continue
        if re.match('Contents/.*/.*\\.appex/embedded.provisionprofile', f):
            continue
        if re.match('Contents/_CodeSignature/CodeResources', f):
            continue
        if f == 'Contents/CodeResources':
            continue
        if re.match('Contents/PlugIns/.*\\.appex/Contents/_CodeSignature', f):
            continue
        if re.match('Contents/Frameworks/.*\\.framework/Versions/A/_CodeSignature', f):
            continue
        result.add(f)
    return result



def remove_plugin_files(files):
    result = set()
    excluded = set()
    for f in files:
        if False and re.match('PlugIns/.*', f):
            excluded.add(f)
        else:
            result.add(f)
    return (result, excluded)


def remove_asset_files(files):
    result = set()
    excluded = set()
    for f in files:
        if re.match('.*\\.car', f):
            excluded.add(f)
        else:
            result.add(f)
    return (result, excluded)


def remove_nib_files(files):
    result = set()
    excluded = set()
    for f in files:
        result.add(f)
    return (result, excluded)


def diff_dirs(app1, dir1, app2, dir2):
    only_in_app1 = dir1.difference(dir2)
    only_in_app2 = dir2.difference(dir1)
    if len(only_in_app1) == 0 and len(only_in_app2) == 0:
        return
    print('Directory structure doesn\'t match in ' + app1 + ' and ' + app2)
    if len(only_in_app1) != 0:
        print('Directories not present in ' + app2)
        for dir in only_in_app1:
            print('    ' + dir)
    if len(only_in_app2) != 0:
        print('Directories not present in ' + app1)
        for dir in only_in_app2:
            print('    ' + dir)

    sys.exit(1)


def is_binary(file):
    out = os.popen('file "' + file + '"').read()
    if out.find('Mach-O') == -1:
        return False
    return True


def is_xcconfig(file):
    if re.match('.*\\.xcconfig', file):
        return True
    else:
        return False


def diff_binaries(tempdir, self_base_path, file1, file2):
    diff_app = tempdir + '/main'
    if not os.path.isfile(diff_app):
        if not os.path.isfile(self_base_path + '/main.cpp'):
            print('Could not find ' + self_base_path + '/main.cpp')
            sys.exit(1)
        subprocess.call(['clang', self_base_path + '/main.cpp', '-lc++', '-o', diff_app])
        if not os.path.isfile(diff_app):
            print('Could not compile ' + self_base_path + '/main.cpp')
            sys.exit(1)

    result = os.popen(diff_app + ' ' + file1 + ' ' + file2).read().strip()
    if result == 'Encrypted':
        return 'binary_encrypted'
    elif result == 'Equal':
        return 'equal'
    elif result == 'Not Equal':
        return 'not_equal'
    else:
        print('Unexpected data from binary diff code: ' + result)
        sys.exit(1)


def is_plist(file1):
    if file1.find('.plist') == -1:
        return False
    return True


def diff_plists(file1, file2):
    remove_properties = ['UISupportedDevices', 'DTAppStoreToolsBuild', 'MinimumOSVersion', 'BuildMachineOSBuild']

    clean1_properties = ''
    clean2_properties = ''

    with open(os.devnull, 'w') as devnull:
        for property in remove_properties:
            if not subprocess.call(['plutil', '-extract', property, 'xml1', '-o', '-', file1], stderr=devnull, stdout=devnull):
                clean1_properties += ' | plutil -remove ' + property + '  -r -o - -- -'
            if not subprocess.call(['plutil', '-extract', property, 'xml1', '-o', '-', file2], stderr=devnull, stdout=devnull):
                clean2_properties += ' | plutil -remove ' + property + '  -r -o - -- -'

    data1 = os.popen('plutil -convert xml1 "' + file1 + '" -o -' + clean1_properties).read()
    data2 = os.popen('plutil -convert xml1 "' + file2 + '" -o -' + clean2_properties).read()

    if data1 == data2:
        return 'equal'
    else:
        with open('lhs.plist', 'wb') as f:
            f.write(str.encode(data1))
        with open('rhs.plist', 'wb') as f:
            f.write(str.encode(data2))
        sys.exit(1)
        return 'not_equal'


def diff_xcconfigs(file1, file2):
    with open(file1, 'rb') as f:
        data1 = f.read().strip()
    with open(file2, 'rb') as f:
        data2 = f.read().strip()
    if data1 != data2:
        return 'not_equal'
    return 'equal'


def diff_files(app1, files1, app2, files2):
    only_in_app1 = files1.difference(files2)
    only_in_app2 = files2.difference(files1)
    if len(only_in_app1) == 0 and len(only_in_app2) == 0:
        return
    if len(only_in_app1) != 0:
        print('Files not present in ' + app2)
        for f in only_in_app1:
            print('    ' + f)
    if len(only_in_app2) != 0:
        print('Files not present in ' + app1)
        for f in only_in_app2:
            print('    ' + f)

    sys.exit(1)


def base_app_dir(path):
    return path


def diff_file(tempdir, self_base_path, path1, path2):
    if is_plist(path1):
        return diff_plists(path1, path2)
    elif is_binary(path1):
        return diff_binaries(tempdir, self_base_path, path1, path2)
    elif is_xcconfig(path1):
        return diff_xcconfigs(path1, path2)
    else:
        if filecmp.cmp(path1, path2):
            return 'equal'
    return 'not_equal'


def appdiff(self_base_path, app1, app2):
    tempdir = tempfile.mkdtemp()

    app1_dir = app1
    app2_dir = app2

    (app1_dirs, app1_files) = get_file_list(base_app_dir(app1_dir))
    (app2_dirs, app2_files) = get_file_list(base_app_dir(app2_dir))

    clean_app1_dirs = remove_codesign_dirs(app1_dirs)
    clean_app2_dirs = remove_codesign_dirs(app2_dirs)

    clean_app1_files = remove_codesign_files(app1_files)
    clean_app2_files = remove_codesign_files(app2_files)

    diff_dirs(app1, clean_app1_dirs, app2, clean_app2_dirs)
    diff_files(app1, clean_app1_files, app2, clean_app2_files)

    clean_app1_files, plugin_app1_files = remove_plugin_files(clean_app1_files)
    clean_app2_files, plugin_app2_files = remove_plugin_files(clean_app2_files)

    clean_app1_files, plugin_app1_files = remove_asset_files(clean_app1_files)
    clean_app2_files, plugin_app2_files = remove_asset_files(clean_app2_files)

    clean_app1_files, nib_app1_files = remove_nib_files(clean_app1_files)
    clean_app2_files, nib_app2_files = remove_nib_files(clean_app2_files)

    different_files = []
    encrypted_files = []
    for relative_file_path in clean_app1_files:
        file_result = diff_file(tempdir, self_base_path, base_app_dir(app1_dir) + '/' + relative_file_path, base_app_dir(app2_dir) + '/' + relative_file_path)
        if file_result == 'equal':
            pass
        elif file_result == 'binary_encrypted':
            encrypted_files.append(relative_file_path)
        else:
            different_files.append(relative_file_path)

    if len(different_files) != 0:
        print('Different files in ' + app1 + ' and ' + app2)
        for relative_file_path in different_files:
            print('    ' + relative_file_path)
    else:
        if len(encrypted_files) != 0:
            print('    Excluded files that couldn\'t be checked due to being encrypted:')
            for relative_file_path in encrypted_files:
                print('        ' + relative_file_path)
        if len(plugin_app1_files) != 0:
            print('    APPs contain PlugIns directory with app extensions. Extensions can\'t currently be checked.')
        if len(nib_app1_files) != 0:
            print('    APPs contain .nib (compiled Interface Builder) files that are compiled by the App Store and can\'t currently be checked:')
            for relative_file_path in nib_app1_files:
                print('        ' + relative_file_path)


if len(sys.argv) != 3:
    print('Usage: appdiff app1 app2')
    sys.exit(1)

appdiff(os.path.dirname(sys.argv[0]), sys.argv[1], sys.argv[2])
