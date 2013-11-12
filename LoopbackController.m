// ================================================================
// Copyright (C) 2007 Google Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// ================================================================
//
//  LoopbackController.m
//  LoopbackFS
//
//  Created by ted on 12/27/07.
//
#import "LoopbackController.h"
#import "LoopbackFS.h"
#import <OSXFUSE/OSXFUSE.h>

#import <AvailabilityMacros.h>

@implementation LoopbackController

- (void)mountFailed:(NSNotification *)notification {
    NSLog(@"Got mountFailed notification.");
    
    NSDictionary* userInfo = [notification userInfo];
    NSError* error = [userInfo objectForKey:kGMUserFileSystemErrorKey];
    NSLog(@"kGMUserFileSystem Error: %@, userInfo=%@", error, [error userInfo]);
    NSRunAlertPanel(@"Mount Failed", [error localizedDescription], nil, nil, nil);
    [[NSApplication sharedApplication] terminate:nil];
}

- (void)didMount:(NSNotification *)notification {
    NSLog(@"Got didMount notification.");
    
    NSDictionary* userInfo = [notification userInfo];
    NSString* mountPath = [userInfo objectForKey:kGMUserFileSystemMountPathKey];
    NSString* parentPath = [mountPath stringByDeletingLastPathComponent];
    [[NSWorkspace sharedWorkspace] selectFile:mountPath
                     inFileViewerRootedAtPath:parentPath];
}

- (void)didUnmount:(NSNotification*)notification {
    NSLog(@"Got didUnmount notification.");
    [loop_ writePbxproj];
    [[NSApplication sharedApplication] terminate:nil];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    [panel setCanChooseFiles:YES];
    [panel setCanChooseDirectories:NO];
    [panel setAllowsMultipleSelection:NO];
    panel.allowedFileTypes = @[ @"xcodeproj" ];
#if MAC_OS_X_VERSION_MIN_REQUIRED >= 1060
    //[panel setDirectoryURL:[NSURL fileURLWithPath:@"/tmp"]];
    int ret = [panel runModal];
#else
    int ret = [panel runModalForDirectory:@"/tmp" file:nil types:nil];
#endif
    if ( ret == NSCancelButton ) {
        exit(0);
    }
#if MAC_OS_X_VERSION_MIN_REQUIRED >= 1060
    NSArray* paths = [panel URLs];
#else
    NSArray* paths = [panel filenames];
#endif
    if ( [paths count] != 1 ) {
        exit(0);
    }
#if MAC_OS_X_VERSION_MIN_REQUIRED >= 1060
    NSString* rootPath = [[paths objectAtIndex:0] path];
#else
    NSString* rootPath = [paths objectAtIndex:0];
#endif
    
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(mountFailed:)
                   name:kGMUserFileSystemMountFailed object:nil];
    [center addObserver:self selector:@selector(didMount:)
                   name:kGMUserFileSystemDidMount object:nil];
    [center addObserver:self selector:@selector(didUnmount:)
                   name:kGMUserFileSystemDidUnmount object:nil];

    double delayInSeconds = 0.2;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self application: NSApp openFile: rootPath];

    });
    
}


- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [fs_ unmount];
    [fs_ release];
    [loop_ release];
    return NSTerminateNow;
}

+ (id)pbxprojDictFromPath: (NSString*)filename rootPath: (NSString**)inOutRootPath
{
    // Find and read the pbjproj file...
    NSString* pbxprojFile = [filename stringByAppendingPathComponent: @"project.pbxproj"];
    NSString* error = nil;
    NSMutableDictionary* d = [NSPropertyListSerialization propertyListFromData: [NSData dataWithContentsOfFile: pbxprojFile]
                                                              mutabilityOption: NSPropertyListMutableContainersAndLeaves
                                                                        format: NULL
                                                              errorDescription: &error];
    

    if (d)
    {
        // choose the parent dir... decent first approximation
        NSString* parent = [filename stringByDeletingLastPathComponent];
        if (inOutRootPath) *inOutRootPath = parent;
        

    }
    
    return d;
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)rootPath
{
    NSString* mountPath = @"/Volumes/loop2";
    NSString* origRoot = rootPath;
    
    NSMutableDictionary* dict = [[self class] pbxprojDictFromPath: rootPath rootPath: &rootPath];
    
    if (!dict)
    {
        NSBeep();
        
        return NO;
    }
    
    loop_ = [[LoopbackFS alloc] initWithRootPath:rootPath pxbproj:dict pathToPbxproj: [origRoot stringByAppendingPathComponent: @"project.pbxproj"]];
    
    fs_ = [[GMUserFileSystem alloc] initWithDelegate:loop_ isThreadSafe:NO];
    
    NSMutableArray* options = [NSMutableArray array];
    NSString* volArg =
    [NSString stringWithFormat:@"volicon=%@",
     [[NSBundle mainBundle] pathForResource:@"LoopbackFS" ofType:@"icns"]];
    [options addObject:volArg];
    
    // Do not use the 'native_xattr' mount-time option unless the underlying
    // file system supports native extended attributes. Typically, the user
    // would be mounting an HFS+ directory through LoopbackFS, so we do want
    // this option in that case.
    [options addObject:@"native_xattr"];
    
    [options addObject:@"volname=LoopbackFS"];
    [fs_ mountAtPath:mountPath withOptions:options];


    return YES;

    // Run through the project, build up a list of all the files that it relies on,
    // and build a map of paths to the mutable objects that reference them.
    
    // Then run the list of files, find the outermost directory containing all of them (making sure it's not / or somethign stupid like that)
    // make a loopback FS starting at that directory
    // mount it
    // Tell the finder to open a window pointing at the project file in the new file system
    
    
}

//- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames
//{
//    for (NSString* file in filenames)
//    {
//        [self application: sender openFile: file];
//    }
//}


@end
