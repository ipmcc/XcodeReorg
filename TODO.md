Right now, this tool doesn't work very well at all. It worked to move things out of the root directory and into sub directories. Everything else was a fail.

I did run into a few things I wanted to make note of before I forget:

1) references from build settings to specific files
    * InfoPlist
    * Prefix headers
    * code signing entitlements
    * I'm sure there are more

2) Header, library search paths - If we move a header file, we have to understand through what mechanism that header was being "found" (i.e. Framework search paths, user search paths, etc) and stitch up whatever setting to point to the new location.

3) Moving git submodules - For fuck's sake is this ever harder than it has to be. I can't even figure out how to do it *by hand* for chrissakes.

4) Groups that are folder relative - You can set the sourceTree parameter to make an Xcode group be relative to a folder and not SRCROOT.

5) It occurs to me that eventually I'd probably like to have a mechanism that temporarily modifies each target in a way that allows us to do a build and capture the "real" environment at build time. This might be necessary to actually understand how all the search paths interrelate