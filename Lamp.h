#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface Lamp : NSObject
- (nullable id)read:(NSString *)key;
- (BOOL)write:(id)value key:(NSString *)key;
@end
NS_ASSUME_NONNULL_END
