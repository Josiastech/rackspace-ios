//
//  Keychain.h
//  OpenStack
//
//  Based on KeychainWrapper in BadassVNC by Dylan Barrie
//
//  Created by Mike Mayo on 10/1/10.
//  The OpenStack project is provided under the Apache 2.0 license.
//

#import <Foundation/Foundation.h>

// This wrapper helps us deal with Keychain-related things 
// such as storing API keys and passwords

@interface Keychain : NSObject {
}

+ (BOOL)setString:(NSString *)string forKey:(NSString *)key;
+ (NSString *)getStringForKey:(NSString *)key;

@end
