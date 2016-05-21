//
// Copyright 2014-2016 Amazon.com,
// Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Amazon Software License (the "License").
// You may not use this file except in compliance with the
// License. A copy of the License is located at
//
//     http://aws.amazon.com/asl/
//
// or in the "license" file accompanying this file. This file is
// distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, express or implied. See the License
// for the specific language governing permissions and
// limitations under the License.
//

#import "AWSCognitoIdentityProvider.h"
#import "AWSCognitoIdentityUser_Internal.h"
#import "AWSCognitoIdentityUserPool_Internal.h"
#import "AWSUICKeyChainStore.h"
#import <CommonCrypto/CommonHMAC.h>
#import "NSData+AWSCognitoIdentityProvider.h"

static AWSUICKeyChainStore *keychain = nil;
static const NSString * AWSCognitoIdentityUserPoolCurrentUser = @"currentUser";

@interface AWSCognitoIdentityUserPool()

@property (nonatomic, strong) AWSCognitoIdentityProvider *client;
@property (nonatomic, strong) AWSServiceConfiguration *configuration;
@property (nonatomic, strong) AWSCognitoIdentityUserPoolConfiguration *userPoolConfiguration;

@end

@interface AWSCognitoIdentityProvider()

- (instancetype)initWithConfiguration:(AWSServiceConfiguration *)configuration;

@end

@implementation AWSCognitoIdentityUserPool

static AWSSynchronizedMutableDictionary *_serviceClients = nil;

+ (void)loadCategories {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        awsbigint_loadBigInt();
    });
}

+ (void)registerCognitoIdentityUserPoolWithUserPoolConfiguration:(AWSCognitoIdentityUserPoolConfiguration *)userPoolConfiguration
                                                          forKey:(NSString *)key {
    if (![AWSServiceManager defaultServiceManager].defaultServiceConfiguration) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:@"`defaultServiceConfiguration` is `nil`. You need to set it before using this method."
                                     userInfo:nil];
    }

    [self registerCognitoIdentityUserPoolWithConfiguration:[AWSServiceManager defaultServiceManager].defaultServiceConfiguration
                                     userPoolConfiguration:userPoolConfiguration
                                                    forKey:key];
}

+ (void)registerCognitoIdentityUserPoolWithConfiguration:(AWSServiceConfiguration *)configuration
                                   userPoolConfiguration:(AWSCognitoIdentityUserPoolConfiguration *)userPoolConfiguration
                                                  forKey:(NSString *)key {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _serviceClients = [AWSSynchronizedMutableDictionary new];
    });
    AWSCognitoIdentityUserPool *identityProvider = [[AWSCognitoIdentityUserPool alloc] initWithConfiguration:configuration
                                                                                       userPoolConfiguration:userPoolConfiguration];
    [_serviceClients setObject:identityProvider
                        forKey:key];
}

+ (instancetype)CognitoIdentityUserPoolForKey:(NSString *)key {
    return [_serviceClients objectForKey:key];
}

+ (void)removeCognitoIdentityUserPoolForKey:(NSString *)key {
    [_serviceClients removeObjectForKey:key];
}

- (instancetype)init {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"`- init` is not a valid initializer. Use `+ defaultCognitoIdentityProvider` or `+ CognitoIdentityProviderForKey:` instead."
                                 userInfo:nil];
    return nil;
}

// Internal init method
- (instancetype)initWithConfiguration:(AWSServiceConfiguration *)configuration
                userPoolConfiguration:(AWSCognitoIdentityUserPoolConfiguration *)userPoolConfiguration; {
    if (self = [super init]) {
        if (configuration) {
            _configuration = [configuration copy];
        } else {
            if (![AWSServiceManager defaultServiceManager].defaultServiceConfiguration) {
                @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                               reason:@"`defaultServiceConfiguration` is `nil`. You need to set it before using this method."
                                             userInfo:nil];
            }
            _configuration = [[AWSServiceManager defaultServiceManager].defaultServiceConfiguration copy];
        }

        _userPoolConfiguration = [userPoolConfiguration copy];

        _client = [[AWSCognitoIdentityProvider alloc] initWithConfiguration:_configuration];
        _userPoolConfiguration = userPoolConfiguration;

        _keychain = [AWSUICKeyChainStore keyChainStoreWithService:[NSString stringWithFormat:@"%@.%@", [NSBundle mainBundle].bundleIdentifier, [AWSCognitoIdentityUserPool class]]];
    }
    return self;
}

- (void) dealloc {
    _delegate = nil;
}

- (AWSTask<AWSCognitoIdentityUserPoolSignUpResponse *>*) signUp: (NSString*) username
                                     password: (NSString*) password
                               userAttributes: (NSArray<AWSCognitoIdentityUserAttributeType *> *) userAttributes
                               validationData: (NSArray<AWSCognitoIdentityUserAttributeType *> *) validationData {
    AWSCognitoIdentityProviderSignUpRequest* request = [AWSCognitoIdentityProviderSignUpRequest new];
    request.clientId = self.userPoolConfiguration.clientId;
    request.username = username;
    request.password = password;
    request.userAttributes = userAttributes;
    request.validationData = [self getValidationData:validationData];
    request.secretHash = [self calculateSecretHash:username];
    return [[self.client signUp:request] continueWithSuccessBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderSignUpResponse *> * _Nonnull task) {
        AWSCognitoIdentityUser * user = [[AWSCognitoIdentityUser alloc] initWithUsername:username pool:self];
        if([task.result.userConfirmed intValue] == AWSCognitoIdentityProviderUserStatusTypeConfirmed){
            user.confirmedStatus = AWSCognitoIdentityUserStatusConfirmed;
        }else if([task.result.userConfirmed intValue] == AWSCognitoIdentityProviderUserStatusTypeUnconfirmed) {
            user.confirmedStatus = AWSCognitoIdentityUserStatusUnconfirmed;
        }
        AWSCognitoIdentityUserPoolSignUpResponse *signupResponse = [AWSCognitoIdentityUserPoolSignUpResponse new];
        [signupResponse aws_copyPropertiesFromObject:task.result];
        signupResponse.user = user;
        return [AWSTask taskWithResult:signupResponse];
    }];
}

- (AWSCognitoIdentityUser*) currentUser {
    return [[AWSCognitoIdentityUser alloc] initWithUsername:[self currentUsername] pool: self];
}

- (NSString*) currentUsername {
    return self.keychain[[self currentUserKey]];
}

- (NSString *) currentUserKey {
    return [NSString stringWithFormat:@"%@.%@", self.userPoolConfiguration.clientId, AWSCognitoIdentityUserPoolCurrentUser];
}

- (void) setCurrentUser:(NSString *) username {
    self.keychain[[self currentUserKey]] = username;
}

- (AWSCognitoIdentityUser*) getUser {
    return [[AWSCognitoIdentityUser alloc] initWithUsername:nil pool:self];
}

- (AWSCognitoIdentityUser*) getUser:(NSString *) username {
    return [[AWSCognitoIdentityUser alloc] initWithUsername:username pool:self];
}

- (void) clearLastKnownUser {
    NSString * currentUserKey = [self currentUserKey];
    if(currentUserKey){
        [self.keychain removeItemForKey:[self currentUserKey]];
    }
}

- (void) clearAll {
    NSArray *keys = keychain.allKeys;
    NSString *keyChainPrefix = [NSString stringWithFormat:@"%@.", self.userPoolConfiguration.clientId];
    for (NSString *key in keys) {
        if([key hasPrefix:keyChainPrefix]){
            [keychain removeItemForKey:key];
        }
    }
}

#pragma mark identity provider
- (NSString *) identityProviderName {
    return [NSString stringWithFormat:@"cognito-idp.us-east-1.amazonaws.com/%@", self.userPoolConfiguration.poolId];
}

- (AWSTask<NSString*>*) token {
    return [[[self currentUser] getSession] continueWithSuccessBlock:^id _Nullable(AWSTask<AWSCognitoIdentityUserSession *> * _Nonnull task) {
        return [AWSTask taskWithResult:task.result.idToken.tokenString];
    }];
}

- (AWSTask<NSDictionary<NSString *, NSString *> *> *)logins {
    return [self.token continueWithSuccessBlock:^id _Nullable(AWSTask<NSString *> * _Nonnull task) {
        return [AWSTask taskWithResult:@{self.identityProviderName:task.result}];
    }];
}

#pragma mark internal

- (NSString *) calculateSecretHash: (NSString*) userName;
{
    if(self.userPoolConfiguration.clientSecret == nil)
        return nil;

    const char *cKey  = [self.userPoolConfiguration.clientSecret cStringUsingEncoding:NSASCIIStringEncoding];
    const char *cData = [[userName stringByAppendingString:self.userPoolConfiguration.clientId] cStringUsingEncoding:NSASCIIStringEncoding];

    unsigned char cHMAC[CC_SHA256_DIGEST_LENGTH];

    CCHmac(kCCHmacAlgSHA256, cKey, strlen(cKey), cData, strlen(cData), cHMAC);

    NSData *HMAC = [[NSData alloc] initWithBytes:cHMAC
                                          length:CC_SHA256_DIGEST_LENGTH];

    return [HMAC base64EncodedStringWithOptions:kNilOptions];
}

AWSCognitoIdentityUserAttributeType* attribute(NSString *name, NSString *value) {
    AWSCognitoIdentityUserAttributeType *attr =  [AWSCognitoIdentityUserAttributeType new];
    attr.name = name;
    attr.value = value;
    return attr;
}

- (NSArray<AWSCognitoIdentityProviderAttributeType *>*)cognitoValidationData {
    UIDevice *device = [UIDevice currentDevice];
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *bundleVersion = [bundle objectForInfoDictionaryKey:(NSString*)kCFBundleVersionKey];
    NSString *bundleShortVersion = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSMutableArray * result = [NSMutableArray new];

    NSArray * atts = @[
                       attribute(@"cognito:iOSVersion", device.systemVersion),
                       attribute(@"cognito:systemName", device.systemName),
                       attribute(@"cognito:deviceName", device.name),
                       attribute(@"cognito:model", device.model),
                       attribute(@"cognito:idForVendor", device.identifierForVendor.UUIDString),
                       attribute(@"cognito:bundleId", bundle.bundleIdentifier),
                       attribute(@"cognito:bundleVersion", bundleVersion),
                       attribute(@"cognito:bundleShortV", bundleShortVersion)
                       ];
    for (AWSCognitoIdentityUserAttributeType *att in atts) {
        if(att.value != nil) {
            [result addObject:att];
        }
    }
    return result;
}

- (NSArray<AWSCognitoIdentityProviderAttributeType*>*)getValidationData:(NSArray<AWSCognitoIdentityUserAttributeType*>*)devProvidedValidationData {
    NSMutableArray *result = [NSMutableArray new];
    if (self.userPoolConfiguration.shouldProvideCognitoValidationData) {
        [result addObjectsFromArray:[self cognitoValidationData]];
    } else {
        if (devProvidedValidationData != nil) {
            for (AWSCognitoIdentityUserAttributeType * attribute in devProvidedValidationData) {
                AWSCognitoIdentityProviderAttributeType *internalType = [AWSCognitoIdentityProviderAttributeType new];
                internalType.name = attribute.name;
                internalType.value = attribute.value;
                [result addObject:internalType];
            }
        }
    }
    return result;
}

@end

@implementation AWSCognitoIdentityUserPoolConfiguration

- (instancetype)initWithClientId:(NSString *)clientId
                    clientSecret:(nullable NSString *)clientSecret
                          poolId:(NSString *)poolId {
    if (self = [super init]) {
        _clientId = clientId;
        _clientSecret = clientSecret;
        _poolId = poolId;
        _shouldProvideCognitoValidationData = YES;
    }

    return self;
}

- (instancetype)initWithClientId:(NSString *)clientId
                    clientSecret:(nullable NSString *)clientSecret
                          poolId:(NSString *)poolId
shouldProvideCognitoValidationData:(BOOL)shouldProvideCognitoValidationData {
    if (self = [super init]) {
        _clientId = clientId;
        _clientSecret = clientSecret;
        _poolId = poolId;
        _shouldProvideCognitoValidationData = shouldProvideCognitoValidationData;
    }

    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    AWSCognitoIdentityUserPoolConfiguration *configuration = [[[self class] allocWithZone:zone] initWithClientId:self.clientId
                                                                                                    clientSecret:self.clientSecret
                                                                                                          poolId:self.poolId
                                                                              shouldProvideCognitoValidationData:self.shouldProvideCognitoValidationData];
    return configuration;
}

@end

@implementation AWSCognitoIdentityPasswordAuthenticationInput
-(instancetype) initWithLastKnownUsername: (NSString *) lastKnownUsername {
    self = [super init];
    if(nil != self){
        self.lastKnownUsername = lastKnownUsername;
    }
    return self;
}
@end

@implementation AWSCognitoIdentityMultifactorAuthenticationInput
-(instancetype) initWithDeliveryMedium: (AWSCognitoIdentityProviderDeliveryMediumType) deliveryMedium destination:(NSString *) destination {
    self = [super init];
    if(nil != self){
        self.deliveryMedium = deliveryMedium;
        self.destination = destination;
    }
    return self;
}
@end

@implementation AWSCognitoIdentityPasswordAuthenticationDetails
-(instancetype) initWithUsername: (NSString *) username
                        password: (NSString *) password {
    self = [super init];
    if(nil != self){
        self.username = username;
        self.password = password;
    }
    return self;
}
@end

@implementation AWSCognitoIdentityUserPoolSignUpResponse

@end
