//
//  OpenStackAccount.m
//  OpenStack
//
//  Created by Mike Mayo on 10/1/10.
//  The OpenStack project is provided under the Apache 2.0 license.
//

#import "OpenStackAccount.h"
#import "Keychain.h"
#import "Provider.h"
#import "Archiver.h"
#import "OpenStackRequest.h"
#import "NSObject+Conveniences.h"
#import "Server.h"
#import "Image.h"
#import "Flavor.h"
#import "AccountManager.h"
#import "LoadBalancer.h"
#import "APICallback.h"


static NSArray *accounts = nil;
static NSMutableDictionary *timers = nil;

@implementation OpenStackAccount

@synthesize uuid, provider, username, projectId, images, flavors, servers, serversURL, filesURL, cdnURL, manager, rateLimits,
            lastUsedFlavorId, lastUsedImageId,
            containerCount, totalBytesUsed, containers, hasBeenRefreshed, flaggedForDelete,
            loadBalancers, lbProtocols, serversByPublicIP, apiVersion, ignoresSSLValidation;

+ (void)initialize {
    accounts = [[Archiver retrieve:@"accounts"] retain];
    if (accounts == nil) {
        accounts = [[NSArray alloc] init];
        [Archiver persist:accounts key:@"accounts"];
    }
    timers = [[NSMutableDictionary alloc] initWithCapacity:[accounts count]];
}

- (NSString *)serversKey {
    return [NSString stringWithFormat:@"%@-servers", self.uuid];
}

- (NSMutableDictionary *)servers {
    if (!serversUnarchived) {
        servers = [[Archiver retrieve:[self serversKey]] retain];
        serversUnarchived = YES;
    }
    return servers;
}

// no sense wasting space by storing sorted arrays, so override the getters to be sure 
// we at least return something

- (NSArray *)sortedImages {
    return [[self.images allValues] sortedArrayUsingSelector:@selector(compare:)];
}

- (NSArray *)sortedFlavors {
    return [[self.flavors allValues] sortedArrayUsingSelector:@selector(compare:)];
}

- (NSArray *)sortedServers {
    return [[self.servers allValues] sortedArrayUsingSelector:@selector(compare:)];
}

- (NSArray *)sortedRateLimits {
    return [self.rateLimits sortedArrayUsingSelector:@selector(compare:)];
}

- (NSArray *)sortedContainers {
    return [[self.containers allValues] sortedArrayUsingSelector:@selector(compare:)];
}

- (NSArray *)sortedLoadBalancers {
    NSMutableArray *allLoadBalancers = [[NSMutableArray alloc] init];
    for (NSString *endpoint in self.loadBalancers) {
        NSDictionary *lbs = [self.loadBalancers objectForKey:endpoint];
        if ([lbs isKindOfClass:[LoadBalancer class]]) {
            NSLog(@"load balancers not persisted properly.  replacing.");
            self.loadBalancers = nil;
            lbs = nil;
            [self persist];
        } else {
            for (NSString *key in lbs) {
                LoadBalancer *lb = [lbs objectForKey:key];
                if (![lb.status isEqualToString:@"PENDING_DELETE"]) {
                    [allLoadBalancers addObject:lb];
                }
            }
        }
        
    }
    NSArray *sortedArray = [NSArray arrayWithArray:[allLoadBalancers sortedArrayUsingSelector:@selector(compare:)]];
    [allLoadBalancers release];
    return sortedArray;
}

- (void)setServers:(NSMutableDictionary *)s {
    if ([servers isEqual:s]) {
        return;
    } else {
        [servers release];
        servers = [s retain];
        
        self.serversByPublicIP = [NSMutableDictionary dictionaryWithCapacity:[self.servers count]];
        for (Server *server in [self.servers allValues]) {
            NSArray *ips = [server.addresses objectForKey:@"public"];
            for (NSString *ip in ips) {
                [self.serversByPublicIP setObject:server forKey:ip];
            }
        }
        
        [Archiver persist:servers key:[self serversKey]];
    }
}

#pragma mark - Collections API Management

- (void)refreshCollections {
    if (!self.manager) {
        self.manager = [[[AccountManager alloc] init] autorelease];
        self.manager.account = self;
    }

    [[self.manager authenticate] success:^(OpenStackRequest *request){
        
        [self.manager getImages];
        [self.manager getFlavors];
        [self.manager getServers];
        
        
        [self.manager getDomains];
        

        [[self.manager getLimits] success:^(OpenStackRequest *request) {
            
            self.rateLimits = [request rateLimits];

        } failure:^(OpenStackRequest *request) {
            
           // failure isn't a big deal, so don't worry about it
            
        }];
        
    } failure:^(OpenStackRequest *request){
    }];
}

#pragma mark -
#pragma mark Serialization

- (void)loadTimer {    
    if (![timers objectForKey:uuid]) {
//        if (!hasBeenRefreshed) {
//            [self refreshCollections];
//        }
        /*
        [NSTimer scheduledTimerWithTimeInterval:4.0 target:self.manager selector:@selector(getServers) userInfo:nil repeats:NO];
        NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:kOpenStackPollingFrequency * 20 target:self selector:@selector(refreshCollections) userInfo:nil repeats:YES];
        [timers setObject:timer forKey:uuid];
         */
    }
}

- (id)copyWithZone:(NSZone *)zone {
    OpenStackAccount *copy = [[OpenStackAccount allocWithZone:zone] init];
    copy.uuid = self.uuid;
    copy.provider = self.provider;
    copy.username = self.username;
    copy.apiKey = self.apiKey;
    copy.authToken = self.authToken;
    
    copy.images = [[[NSMutableDictionary alloc] initWithDictionary:self.images] autorelease];
    copy.flavors = [[[NSDictionary alloc] initWithDictionary:self.flavors] autorelease];
    /*
    copy.servers = [[NSMutableDictionary alloc] initWithDictionary:self.servers];
    copy.containers = self.containers;
    copy.loadBalancers = self.loadBalancers;
    copy.serversByPublicIP = self.serversByPublicIP;
    */
    
    copy.serversURL = self.serversURL;
    copy.filesURL = self.filesURL;
    copy.cdnURL = self.cdnURL;
    copy.rateLimits = [[[NSArray alloc] initWithArray:self.rateLimits] autorelease];
    copy.lastUsedFlavorId = self.lastUsedFlavorId;
    copy.lastUsedImageId = self.lastUsedImageId;
    copy.containerCount = self.containerCount;
    copy.totalBytesUsed = self.totalBytesUsed;
    copy.apiVersion = self.apiVersion;
    copy.ignoresSSLValidation = self.ignoresSSLValidation;
    manager = [[AccountManager alloc] init];
    manager.account = copy;
    return copy;
}

- (void)encodeWithCoder: (NSCoder *)coder {
    [coder encodeObject:uuid forKey:@"uuid"];
    [coder encodeObject:provider forKey:@"provider"];
    [coder encodeObject:username forKey:@"username"];
    
    [coder encodeObject:serversURL forKey:@"serversURL"];
    [coder encodeObject:filesURL forKey:@"filesURL"];
    [coder encodeObject:cdnURL forKey:@"cdnURL"];
    [coder encodeObject:rateLimits forKey:@"rateLimits"];
    [coder encodeObject:lastUsedFlavorId forKey:@"lastUsedFlavorId"];
    [coder encodeObject:lastUsedImageId forKey:@"lastUsedImageId"];
    [coder encodeInt:containerCount forKey:@"containerCount"];
    [coder encodeInt:totalBytesUsed forKey:@"totalBytesUsed"];
    
    [coder encodeObject:images forKey:@"images"];
    [coder encodeObject:flavors forKey:@"flavors"];
    
    [coder encodeBool:ignoresSSLValidation forKey:@"ignoresSSLValidation"];
    
    /*
    [coder encodeObject:servers forKey:@"servers"];
    [coder encodeObject:serversByPublicIP forKey:@"serversByPublicIP"];
    [coder encodeObject:containers forKey:@"containers"];
    [coder encodeObject:loadBalancers forKey:@"loadBalancers"];
    */
    
    [coder encodeObject:apiVersion forKey:@"apiVersion"];
}

- (id)decode:(NSCoder *)coder key:(NSString *)key {    
    @try {
        return [[coder decodeObjectForKey:key] retain];
    }
    @catch (NSException *exception) {
        return nil;
    }
}

- (id)initWithCoder:(NSCoder *)coder {
    if ((self = [super init])) {
        uuid = [self decode:coder key:@"uuid"];
        provider = [self decode:coder key:@"provider"];
        username = [self decode:coder key:@"username"];

        images = [self decode:coder key:@"images"];
        
        // make sure images stored aren't corrupt
        if ([images count] > 0) {
            for (id obj in [images allValues]) {
                if (![obj isKindOfClass:[Image class]]) {
                    images = nil;
                    break;
                }
            }
        }        
        
        flavors = [self decode:coder key:@"flavors"];
        servers = [self decode:coder key:@"servers"];
        serversByPublicIP = [self decode:coder key:@"serversByPublicIP"];
        
        serversURL = [self decode:coder key:@"serversURL"];
        filesURL = [self decode:coder key:@"filesURL"];
        cdnURL = [self decode:coder key:@"cdnURL"];
        rateLimits = [self decode:coder key:@"rateLimits"];

        [self loadTimer];
        
        lastUsedFlavorId = [self decode:coder key:@"lastUserFlavorId"];
        lastUsedImageId = [self decode:coder key:@"lastUsedImageId"];
        
        containerCount = [coder decodeIntForKey:@"containerCount"];
        //totalBytesUsed = [coder decodeIntForKey:@"totalBytesUsed"];
        
        containers = [self decode:coder key:@"containers"];
        loadBalancers = [self decode:coder key:@"loadBalancers"];

        apiVersion = [self decode:coder key:@"apiVersion"];
        if (!apiVersion) {
            NSString *component = [[[provider.authEndpointURL description] componentsSeparatedByString:@"/"] lastObject];
            if ([component isEqualToString:@"v1.1"]) {
                self.apiVersion = @"1.1";
            } else {
                self.apiVersion = component;
            }
        }
        
        ignoresSSLValidation = [coder decodeBoolForKey:@"ignoresSSLValidation"];
        
        manager = [[AccountManager alloc] init];
        manager.account = self;
    }
    return self;
}

- (id)init {
    if ((self = [super init])) {
        uuid = [[NSString alloc] initWithString:[OpenStackAccount stringWithUUID]];

        [self loadTimer];
        
        manager = [[AccountManager alloc] init];
        manager.account = self;
    }
    return self;
}

+ (NSArray *)accounts {
    if (accounts == nil) {
        accounts = [[Archiver retrieve:@"accounts"] retain];
    }
    return accounts;
}

+ (void)persist:(NSArray *)accountArray {
    accounts = [[NSArray arrayWithArray:accountArray] retain];
    [Archiver persist:accounts key:@"accounts"];
    [accounts release];
    accounts = nil;
}

- (void)persist {
    //return NO;
    //*
    if (!flaggedForDelete) {        
        NSMutableArray *accountArr = [NSMutableArray arrayWithArray:[OpenStackAccount accounts]];
        
        BOOL accountPresent = NO;
        for (int i = 0; i < [accountArr count]; i++) {
            OpenStackAccount *account = [accountArr objectAtIndex:i];
            
            if ([account.uuid isEqualToString:self.uuid]) {
                accountPresent = YES;
                [accountArr replaceObjectAtIndex:i withObject:self];
                break;
            }
        }
            
        if (!accountPresent) {
            [accountArr insertObject:self atIndex:0];
        }
        
        [Archiver persist:[NSArray arrayWithArray:accountArr] key:@"accounts"];    
        [accounts release];
        accounts = nil;
        //return result;
    }     //*/
}

// the API key and auth token are stored in the Keychain, so overriding the 
// getter and setter to abstract the encryption away and make it easy to use

- (NSString *)apiKeyKeychainKey {
    return [NSString stringWithFormat:@"%@-apiKey", self.uuid];
}

- (NSString *)apiKey {    
    return [Keychain getStringForKey:[self apiKeyKeychainKey]];
}

- (void)setApiKey:(NSString *)newAPIKey {
    [Keychain setString:newAPIKey forKey:[self apiKeyKeychainKey]];
}

- (NSString *)authTokenKeychainKey {
    return [NSString stringWithFormat:@"%@-authToken", self.uuid];
}

- (NSString *)authToken {
    NSString *authToken = [Keychain getStringForKey:[self authTokenKeychainKey]];
    if (!authToken) {
        authToken = @"";
    }
    return authToken;
}

- (void)setAuthToken:(NSString *)newAuthToken {
    [Keychain setString:newAuthToken forKey:[self authTokenKeychainKey]];
}

- (NSString *)accountNumber {
    NSString *accountNumber = nil;
    if (self.serversURL) {
        NSString *surl = [self.serversURL description];
        accountNumber = [[surl componentsSeparatedByString:@"/"] lastObject];
    }
    return accountNumber;
}

- (BOOL)usesHumanPassword {
    return [self.apiVersion isEqualToString:@"2.0"];
}

- (NSString *)loadBalancerEndpointForRegion:(NSString *)region {
    NSString *accountNumber = [self accountNumber];
    if ([self.provider isRackspaceUS]) {
        if ([region isEqualToString:@"DFW"]) {
            return [NSString stringWithFormat:@"https://dfw.loadbalancers.api.rackspacecloud.com/v1.0/%@", accountNumber];
        } else if ([region isEqualToString:@"ORD"]) {
            return [NSString stringWithFormat:@"https://ord.loadbalancers.api.rackspacecloud.com/v1.0/%@", accountNumber];
        } else {
            return @"";
        }
    } else if ([self.provider isRackspaceUK]) {
        return [NSString stringWithFormat:@"https://lon.loadbalancers.api.rackspacecloud.com/v1.0/%@", accountNumber];        
    } else {
        return @"";
    }
}

- (NSString *)loadBalancerRegionForEndpoint:(NSString *)endpoint {
    NSString *component = [[endpoint componentsSeparatedByString:@"."] objectAtIndex:0];
    component = [[component componentsSeparatedByString:@"//"] objectAtIndex:1];
    return [component uppercaseString];
}

- (NSArray *)loadBalancerURLs {
    NSString *accountNumber = [self accountNumber];
    
    if (accountNumber && [self.provider isRackspace]) {        
        if ([self.provider isRackspaceUS]) {
            NSString *ord = [NSString stringWithFormat:@"https://ord.loadbalancers.api.rackspacecloud.com/v1.0/%@", accountNumber];
            NSString *dfw = [NSString stringWithFormat:@"https://dfw.loadbalancers.api.rackspacecloud.com/v1.0/%@", accountNumber];
            return [NSArray arrayWithObjects:ord, dfw, nil];
        } else if ([self.provider isRackspaceUK]) {
            NSString *lon = [NSString stringWithFormat:@"https://lon.loadbalancers.api.rackspacecloud.com/v1.0/%@", accountNumber];
            return [NSArray arrayWithObjects:lon, nil];
        } else {
            return nil;
        }
    } else {
        return nil;
    }
}

- (NSURL *)dnsURL {
    NSString *accountNumber = [self accountNumber];
    
    if (accountNumber && [self.provider isRackspace]) {
        if ([self.provider isRackspaceUS]) {
            return [NSString stringWithFormat:@"https://dns.api.rackspacecloud.com/v1.0/%@", accountNumber];
        } else if ([self.provider isRackspaceUK]) {
            return [NSString stringWithFormat:@"https://lon.dns.api.rackspacecloud.com/v1.0/%@", accountNumber];
        } else {
            return nil;
        }
    } else {
        return nil;
    }
}

- (NSArray *)loadBalancerRegions {
    NSString *accountNumber = [self accountNumber];
    
    if (accountNumber && [self.provider isRackspace]) {        
        if ([self.provider isRackspaceUS]) {
            return [NSArray arrayWithObjects:@"ORD", @"DFW", nil];
        } else if ([self.provider isRackspaceUK]) {
            return [NSArray arrayWithObjects:@"LON", nil];
        } else {
            return [NSArray array];
        }
    } else {
        return [NSArray array];
    }
}

#pragma mark - Memory Management

- (void)dealloc {
    NSTimer *timer = [timers objectForKey:uuid];
    [timer invalidate];
    [timers removeObjectForKey:uuid];
    
    [uuid release];
    [manager release];
    [provider release];
    [username release];
    [projectId release];
    [flavors release];
    [images release];
    [servers release];
    [serversURL release];
    [filesURL release];
    [cdnURL release];
    [rateLimits release];
    [containers release];
    [loadBalancers release];
    [lbProtocols release];
    [serversByPublicIP release];
    [lastUsedFlavorId release];
    [lastUsedImageId release];
    [apiVersion release];
    
    [super dealloc];
}

@end
