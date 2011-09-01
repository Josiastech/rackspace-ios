//
//  NSString+Conveniences.h
//  OpenStack
//
//  Created by Mike Mayo on 10/9/10.
//  The OpenStack project is provided under the Apache 2.0 license.
//

#import <Foundation/Foundation.h>


@interface NSString (Conveniences)

- (BOOL)isURL;
- (NSString *)replace:(NSString *)s with:(NSString *)r;
- (NSString *)replace:(NSString *)s withInt:(NSInteger )i;

@end
