# GitMCDecomp

This is a forked version of [GitMCDecomp](https://github.com/Nickid2018/GitMCDecomp), added a script to build all version without configuration.

## Usage
- Install JDK 17+ and PowerShell
- Clone this repository
- Build the Java part of this project `gradle shadowJar`
- Run the build script to import build cmdlets `PS> . build.ps1`
- Run `New-McdeRepository` to make a empty repository
- Run `Build-McdeAllVersion` to start building.

`Build-McdeAllVersion` flags:
    - `-ExcludeSnapshots`: Only build release versions
    - `-NoMirror`: Directly download from Mojang server, not BMCLAPI
