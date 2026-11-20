#import "Lamp.h"
#import <dlfcn.h>
@protocol BrightnessClient
- (id)copyPropertyForKey:(NSString *)key;
- (BOOL)setProperty:(id)value forKey:(NSString *)key;
@end
@implementation Lamp {
    NSObject<BrightnessClient> *_client;
}
- (instancetype)init {
    if ((self = [super init])) {
        dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_NOW);
        _client = [NSClassFromString(@"BrightnessSystemClient") new];
    }
    return self;
}
- (id)read:(NSString *)key {
    if (![_client respondsToSelector:@selector(copyPropertyForKey:)]) return nil;
    return [_client copyPropertyForKey:key];
}
- (BOOL)write:(id)value key:(NSString *)key {
    if (![_client respondsToSelector:@selector(setProperty:forKey:)]) return NO;
    return [_client setProperty:value forKey:key];
}
@end
