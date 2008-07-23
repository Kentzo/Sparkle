//
//  SUHost.m
//  Sparkle
//
//  Copyright 2008 Andy Matuschak. All rights reserved.
//

#import "Sparkle.h"
#import <sys/mount.h> // For statfs for isRunningOnReadOnlyVolume

@implementation SUHost

- (id)initWithBundle:(NSBundle *)aBundle
{
    if (aBundle == nil) aBundle = [NSBundle mainBundle];
	if ((self = [super init]))
	{
        bundle = [aBundle retain];
    }
    return self;
}

- (void)dealloc
{
	[bundle release];
	[super dealloc];
}

- (NSBundle *)bundle
{
    return bundle;
}

- (NSString *)bundlePath
{
    return [bundle bundlePath];
}

- (NSString *)name
{
	NSString *name = [bundle objectForInfoDictionaryKey:@"CFBundleDisplayName"];
	if (name) return name;
	
	name = [self objectForInfoDictionaryKey:@"CFBundleName"];
	if (name) return name;
	
	return [[[NSFileManager defaultManager] displayNameAtPath:[bundle bundlePath]] stringByDeletingPathExtension];
}

- (NSString *)version
{
	return [bundle objectForInfoDictionaryKey:@"CFBundleVersion"];
}

- (NSString *)displayVersion
{
	NSString *shortVersionString = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
	if (shortVersionString)
		return shortVersionString;
	else
		return [self version]; // Fall back on the normal version string.
}

- (NSImage *)icon
{
	// Cache the application icon.
	NSString *iconPath = [bundle pathForResource:[bundle objectForInfoDictionaryKey:@"CFBundleIconFile"] ofType:@"icns"];
	// According to the OS X docs, "CFBundleIconFile - This key identifies the file containing
	// the icon for the bundle. The filename you specify does not need to include the .icns
	// extension, although it may."
	//
	// However, if it *does* include the '.icns' the above method fails (tested on OS X 10.3.9) so we'll also try:
	if (!iconPath)
		iconPath = [bundle pathForResource:[bundle objectForInfoDictionaryKey:@"CFBundleIconFile"] ofType: nil];
	NSImage *icon = [[[NSImage alloc] initWithContentsOfFile:iconPath] autorelease];
	// Use a default icon if none is defined.
	if (!icon) { icon = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericApplicationIcon)]; }
	return icon;
}

- (BOOL)isRunningOnReadOnlyVolume
{	
	struct statfs statfs_info;
	statfs([[bundle bundlePath] fileSystemRepresentation], &statfs_info);
	return (statfs_info.f_flags & MNT_RDONLY);
}

- (BOOL)isBackgroundApplication
{
	return [[bundle objectForInfoDictionaryKey:@"LSUIElement"] doubleValue];
}

- (NSString *)publicDSAKey
{
	// Maybe the key is just a string in the Info.plist.
	NSString *key = [bundle objectForInfoDictionaryKey:SUPublicDSAKeyKey];
	if (key) { return key; }
	
	// More likely, we've got a reference to a Resources file by filename:
	NSString *keyFilename = [self objectForInfoDictionaryKey:SUPublicDSAKeyFileKey];
	if (!keyFilename) { return nil; }
	return [NSString stringWithContentsOfFile:[bundle pathForResource:keyFilename ofType:nil]];
}

- (NSArray *)systemProfile
{
	return [[SUSystemProfiler sharedSystemProfiler] systemProfileArrayForHost:self];
}

- (id)objectForInfoDictionaryKey:(NSString *)key
{
    return [bundle objectForInfoDictionaryKey:key];
}

- (BOOL)boolForInfoDictionaryKey:(NSString *)key
{
	return [[self objectForInfoDictionaryKey:key] boolValue];
}

- (id)objectForUserDefaultsKey:(NSString *)defaultName
{
	CFPropertyListRef obj = CFPreferencesCopyAppValue((CFStringRef)defaultName, (CFStringRef)[bundle bundleIdentifier]);
	// Under Tiger, CFPreferencesCopyAppValue doesn't get values from NSRegistratioDomain, so anything
	// passed into -[NSUserDefaults registerDefaults:] is ignored.  The following line falls
	// back to using NSUserDefaults, but only if the host bundle is the main bundle, and no value
	// is found elsewhere.
	if (obj == NULL && bundle != [NSBundle mainBundle])
		obj = [[NSUserDefaults standardUserDefaults] objectForKey:defaultName];
#if MAC_OS_X_VERSION_MIN_REQUIRED > 1050
	return [NSMakeCollectable(obj) autorelease];
#else
	return [(id)obj autorelease];
#endif	
}

- (void)setObject:(id)value forUserDefaultsKey:(NSString *)defaultName;
{
	CFPreferencesSetValue((CFStringRef)defaultName, value, (CFStringRef)[bundle bundleIdentifier],  kCFPreferencesCurrentUser,  kCFPreferencesAnyHost);
	CFPreferencesSynchronize((CFStringRef)[bundle bundleIdentifier], kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
	// If anything's bound to this through an NSUserDefaultsController, it won't know that anything's changed.
	// We can't get an NSUserDefaults object for anything other than the standard one for the app, so this won't work for bundles.
	// But it's the best we can do: this will make NSUserDefaultsControllers know about the changes that have been made.
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)boolForUserDefaultsKey:(NSString *)defaultName
{
	if (bundle == [NSBundle mainBundle])
		return [[NSUserDefaults standardUserDefaults] boolForKey:defaultName];
	
	BOOL value;
	CFPropertyListRef plr = CFPreferencesCopyAppValue((CFStringRef)defaultName, (CFStringRef)[bundle bundleIdentifier]);
	if (plr == NULL)
		value = NO;
	else
	{
		value = (BOOL)CFBooleanGetValue((CFBooleanRef)plr);
		CFRelease(plr);
	}
	return value;
}

- (void)setBool:(BOOL)value forUserDefaultsKey:(NSString *)defaultName
{
	CFPreferencesSetValue((CFStringRef)defaultName, (CFBooleanRef)[NSNumber numberWithBool:value], (CFStringRef)[bundle bundleIdentifier],  kCFPreferencesCurrentUser,  kCFPreferencesAnyHost);
	CFPreferencesSynchronize((CFStringRef)[bundle bundleIdentifier], kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
	// If anything's bound to this through an NSUserDefaultsController, it won't know that anything's changed.
	// We can't get an NSUserDefaults object for anything other than the standard one for the app, so this won't work for bundles.
	// But it's the best we can do: this will make NSUserDefaultsControllers know about the changes that have been made.	
	[[NSUserDefaults standardUserDefaults] synchronize];
}

@end
