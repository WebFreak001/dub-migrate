// linux & mac forward-compatibility DUB package directory linking script
import std.algorithm;
import std.conv;
import std.exception;
import std.file;
import std.format;
import std.path;
import std.process;
import std.stdio;
import std.string;
import std.utf;

int main(string[] args)
{
	try migrate();
	catch (Exception e) {
		stderr.writeln("Failed migrating: ", e.msg);
		debug stderr.writeln(e);
		return 1;
	}
	return 0;
}

void migrate()
{
	string dubPackages = environment.get("DUB_HOME", fallbackHome).buildPath("packages");
	if (auto dubHome = environment.get("DUB_HOME"))
		dubPackages = dubHome.buildPath("packages");

	if (!exists(dubPackages) || !isDir(dubPackages))
		throw new Exception("DUB package directory does not exist, try specifying DUB_HOME - tried " ~ dubPackages);

	int migrated;
	foreach (dir; dirEntries(dubPackages, SpanMode.shallow))
	{
		auto lockFile = dirEntries(dir, SpanMode.shallow).find!(a => a.name.endsWith(".lock"));
		if (lockFile.empty)
			continue;

		auto pkgName = lockFile.front.baseName[0 .. $ - 5];
		if (!exists(dubPackages.buildPath(pkgName)))
			mkdir(dubPackages.buildPath(pkgName));

		auto ver = dir.baseName;
		enforce(ver.startsWith(pkgName ~ "-"), format!"Directory '%s' has '%s' file, but is not named '%s'"(dir, lockFile.front, pkgName));
		ver = ver[pkgName.length + 1 .. $];

		string oldPath = dir.name;
		enforce(oldPath.exists, format!"Directory '%s' is expected to exist"(oldPath));
		string newPath = dubPackages.buildPath(pkgName, ver);
		if (newPath.exists)
			continue;
		writeln("mv ", oldPath, " ", newPath);
		rename(oldPath, newPath);
		writeln("ln ", newPath, " ", oldPath);
		linkOrCopy(newPath, oldPath);
		migrated++;
	}
	if (!migrated)
		writeln("No packages to migrate");
	else
		writeln("Successfully migrated ", migrated, " packages");
}

string fallbackHome()
{
	if (auto dpath = environment.get("DPATH"))
		return dpath.buildPath("dub");
	else
		return environment["HOME"].buildPath(".dub");
}

void linkOrCopy(string from, string to)
{
	version (Posix)
	{
		symlink(from, to);
		return;
	}
	// fallback to copy
	copy(from, to, PreserveAttributes.yes);
}

