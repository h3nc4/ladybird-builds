# Copyright (C) 2026  Henrique Almeida
# This file is part of Ladybird Builds.
#
# Ladybird Builds is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Ladybird Builds is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Ladybird Builds.  If not, see <https://www.gnu.org/licenses/>.

# Usage: shard.py <index>/<count> <jobs>, run from the Ladybird checkout
import concurrent.futures
import json
import subprocess
import sys

index, count = (int(n) for n in sys.argv[1].split("/"))
# compile_commands.json drops the -MD flags ninja passes, and ccache then hashes every compile differently.
with open("Build/distribution/compdb.json") as file:
    entries = [entry for entry in json.load(file) if entry["output"].endswith(".o")][index::count]


# Ninja would first build every library an object depends on. Running each command directly skips that.
# A compile missing a header that only the full build generates is left to that build.
def compile_entry(entry):
    command = entry["command"]
    if "ccache" not in command.split(" ", 1)[0]:
        command = "ccache " + command
    result = subprocess.run(command, shell=True, cwd=entry["directory"], capture_output=True, text=True)
    return entry["file"], result.returncode, result.stderr


with concurrent.futures.ThreadPoolExecutor(int(sys.argv[2])) as pool:
    failures = [(file, stderr) for file, code, stderr in pool.map(compile_entry, entries) if code != 0]

for file, stderr in failures[:3]:
    print(f"{file}:\n{stderr[:2000]}")
print(f"shard {sys.argv[1]}: {len(entries)} compiles, {len(failures)} failed")
