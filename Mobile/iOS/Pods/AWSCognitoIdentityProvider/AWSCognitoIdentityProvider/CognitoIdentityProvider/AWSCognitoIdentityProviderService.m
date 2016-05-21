//
// Copyright 2010-2016 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License").
// You may not use this file except in compliance with the License.
// A copy of the License is located at
//
// http://aws.amazon.com/apache2.0
//
// or in the "license" file accompanying this file. This file is distributed
// on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
// express or implied. See the License for the specific language governing
// permissions and limitations under the License.
//

#import "AWSCognitoIdentityProvider.h"

#import "AWSNetworking.h"
#import "AWSSignature.h"
#import "AWSService.h"
#import "AWSCategory.h"
#import "AWSNetworking.h"
#import "AWSURLRequestSerialization.h"
#import "AWSURLResponseSerialization.h"
#import "AWSURLRequestRetryHandler.h"
#import "AWSSynchronizedMutableDictionary.h"
#import "AWSCognitoIdentityProviderResources.h"

static NSString *const AWSCognitoIdentityProviderSDKVersion = @"2.4.1";

@interface AWSCognitoIdentityProviderResponseSerializer : AWSJSONResponseSerializer

@end

@implementation AWSCognitoIdentityProviderResponseSerializer

#pragma mark - Service errors

static NSDictionary *errorCodeDictionary = nil;
+ (void)initialize {
    errorCodeDictionary = @{
                            @"IncompleteSignature" : @(AWSCognitoIdentityProviderErrorIncompleteSignature),
                            @"InvalidClientTokenId" : @(AWSCognitoIdentityProviderErrorInvalidClientTokenId),
                            @"MissingAuthenticationToken" : @(AWSCognitoIdentityProviderErrorMissingAuthenticationToken),
                            @"AliasExistsException" : @(AWSCognitoIdentityProviderErrorAliasExists),
                            @"CodeMismatchException" : @(AWSCognitoIdentityProviderErrorCodeMismatch),
                            @"ConcurrentModificationException" : @(AWSCognitoIdentityProviderErrorConcurrentModification),
                            @"ExpiredCodeException" : @(AWSCognitoIdentityProviderErrorExpiredCode),
                            @"InternalErrorException" : @(AWSCognitoIdentityProviderErrorInternalError),
                            @"InvalidLambdaResponseException" : @(AWSCognitoIdentityProviderErrorInvalidLambdaResponse),
                            @"InvalidParameterException" : @(AWSCognitoIdentityProviderErrorInvalidParameter),
                            @"InvalidPasswordException" : @(AWSCognitoIdentityProviderErrorInvalidPassword),
                            @"NotAuthorizedException" : @(AWSCognitoIdentityProviderErrorNotAuthorized),
                            @"ResourceNotFoundException" : @(AWSCognitoIdentityProviderErrorResourceNotFound),
                            @"TooManyFailedAttemptsException" : @(AWSCognitoIdentityProviderErrorTooManyFailedAttempts),
                            @"TooManyRequestsException" : @(AWSCognitoIdentityProviderErrorTooManyRequests),
                            @"UnexpectedLambdaException" : @(AWSCognitoIdentityProviderErrorUnexpectedLambda),
                            @"UserLambdaValidationException" : @(AWSCognitoIdentityProviderErrorUserLambdaValidation),
                            };
}

#pragma mark -

- (id)responseObjectForResponse:(NSHTTPURLResponse *)response
                originalRequest:(NSURLRequest *)originalRequest
                 currentRequest:(NSURLRequest *)currentRequest
                           data:(id)data
                          error:(NSError *__autoreleasing *)error {
    id responseObject = [super responseObjectForResponse:response
                                         originalRequest:originalRequest
                                          currentRequest:currentRequest
                                                    data:data
                                                   error:error];
    if (!*error && [responseObject isKindOfClass:[NSDictionary class]]) {
        if ([errorCodeDictionary objectForKey:[[[responseObject objectForKey:@"__type"] componentsSeparatedByString:@"#"] lastObject]]) {
            if (error) {
                *error = [NSError errorWithDomain:AWSCognitoIdentityProviderErrorDomain
                                             code:[[errorCodeDictionary objectForKey:[[[responseObject objectForKey:@"__type"] componentsSeparatedByString:@"#"] lastObject]] integerValue]
                                         userInfo:responseObject];
            }
            return responseObject;
        } else if ([[[responseObject objectForKey:@"__type"] componentsSeparatedByString:@"#"] lastObject]) {
            if (error) {
                *error = [NSError errorWithDomain:AWSCognitoIdentityProviderErrorDomain
                                             code:AWSCognitoIdentityProviderErrorUnknown
                                         userInfo:responseObject];
            }
            return responseObject;
        }
    }

    if (!*error && response.statusCode/100 != 2) {
        *error = [NSError errorWithDomain:AWSCognitoIdentityProviderErrorDomain
                                     code:AWSCognitoIdentityProviderErrorUnknown
                                 userInfo:nil];
    }

    if (!*error && [responseObject isKindOfClass:[NSDictionary class]]) {
        if (self.outputClass) {
            responseObject = [AWSMTLJSONAdapter modelOfClass:self.outputClass
                                          fromJSONDictionary:responseObject
                                                       error:error];
        }
    }

    return responseObject;
}

@end

@interface AWSCognitoIdentityProviderRequestRetryHandler : AWSURLRequestRetryHandler

@end

@implementation AWSCognitoIdentityProviderRequestRetryHandler

- (AWSNetworkingRetryType)shouldRetry:(uint32_t)currentRetryCount
                             response:(NSHTTPURLResponse *)response
                                 data:(NSData *)data
                                error:(NSError *)error {
    AWSNetworkingRetryType retryType = [super shouldRetry:currentRetryCount
                                                 response:response
                                                     data:data
                                                    error:error];
    if(retryType == AWSNetworkingRetryTypeShouldNotRetry
       && [error.domain isEqualToString:AWSCognitoIdentityProviderErrorDomain]
       && currentRetryCount < self.maxRetryCount) {
        switch (error.code) {
            case AWSCognitoIdentityProviderErrorIncompleteSignature:
            case AWSCognitoIdentityProviderErrorInvalidClientTokenId:
            case AWSCognitoIdentityProviderErrorMissingAuthenticationToken:
                retryType = AWSNetworkingRetryTypeShouldRefreshCredentialsAndRetry;
                break;

            default:
                break;
        }
    }

    return retryType;
}

@end

@interface AWSRequest()

@property (nonatomic, strong) AWSNetworkingRequest *internalRequest;

@end

@interface AWSCognitoIdentityProvider()

@property (nonatomic, strong) AWSNetworking *networking;
@property (nonatomic, strong) AWSServiceConfiguration *configuration;

@end

@interface AWSServiceConfiguration()

@property (nonatomic, strong) AWSEndpoint *endpoint;

@end

@implementation AWSCognitoIdentityProvider

static AWSSynchronizedMutableDictionary *_serviceClients = nil;

+ (void)initialize {
    [super initialize];

    if (![AWSiOSSDKVersion isEqualToString:AWSCognitoIdentityProviderSDKVersion]) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:[NSString stringWithFormat:@"AWSCore and AWSCognitoIdentityProvider versions need to match. Check your SDK installation. AWSCore: %@ AWSCognitoIdentityProvider: %@", AWSiOSSDKVersion, AWSCognitoIdentityProviderSDKVersion]
                                     userInfo:nil];
    }
}
+ (instancetype)defaultCognitoIdentityProvider {
    if (![AWSServiceManager defaultServiceManager].defaultServiceConfiguration) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:@"`defaultServiceConfiguration` is `nil`. You need to set it before using this method."
                                     userInfo:nil];
    }
    
    static AWSCognitoIdentityProvider *_defaultCognitoIdentityProvider = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        _defaultCognitoIdentityProvider = [[AWSCognitoIdentityProvider alloc] initWithConfiguration:AWSServiceManager.defaultServiceManager.defaultServiceConfiguration];
#pragma clang diagnostic pop
    });
    
    return _defaultCognitoIdentityProvider;
}

+ (void)registerCognitoIdentityProviderWithConfiguration:(AWSServiceConfiguration *)configuration forKey:(NSString *)key {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _serviceClients = [AWSSynchronizedMutableDictionary new];
    });
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [_serviceClients setObject:[[AWSCognitoIdentityProvider alloc] initWithConfiguration:configuration]
                        forKey:key];
#pragma clang diagnostic pop
}

+ (instancetype)CognitoIdentityProviderForKey:(NSString *)key {
    return [_serviceClients objectForKey:key];
}

+ (void)removeCognitoIdentityProviderForKey:(NSString *)key {
    [_serviceClients removeObjectForKey:key];
}

- (instancetype)init {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"`- init` is not a valid initializer. Use `+ defaultCognitoIdentityProvider` or `+ CognitoIdentityProviderForKey:` instead."
                                 userInfo:nil];
    return nil;
}


- (instancetype)initWithConfiguration:(AWSServiceConfiguration *)configuration {
    if (self = [super init]) {
        _configuration = [configuration copy];

        _configuration.endpoint = [[AWSEndpoint alloc] initWithRegion:_configuration.regionType
                                                              service:AWSServiceCognitoIdentityProvider
                                                         useUnsafeURL:NO];

        AWSSignatureV4Signer *signer = [[AWSSignatureV4Signer alloc] initWithCredentialsProvider:_configuration.credentialsProvider
                                                                                        endpoint:_configuration.endpoint];
        AWSNetworkingRequestInterceptor *baseInterceptor = [[AWSNetworkingRequestInterceptor alloc] initWithUserAgent:_configuration.userAgent];
        _configuration.requestInterceptors = @[baseInterceptor, signer];

        _configuration.baseURL = _configuration.endpoint.URL;
        _configuration.requestSerializer = [AWSJSONRequestSerializer new];
        _configuration.retryHandler = [[AWSCognitoIdentityProviderRequestRetryHandler alloc] initWithMaximumRetryCount:_configuration.maxRetryCount];
        _configuration.headers = @{@"Content-Type" : @"application/x-amz-json-1.1"};

        _networking = [[AWSNetworking alloc] initWithConfiguration:_configuration];
    }

    return self;
}

- (AWSTask *)invokeRequest:(AWSRequest *)request
               HTTPMethod:(AWSHTTPMethod)HTTPMethod
                URLString:(NSString *) URLString
             targetPrefix:(NSString *)targetPrefix
            operationName:(NSString *)operationName
              outputClass:(Class)outputClass {
    
    @autoreleasepool {
        if (!request) {
            request = [AWSRequest new];
        }
        
        AWSNetworkingRequest *networkingRequest = request.internalRequest;
        if (request) {
            networkingRequest.parameters = [[AWSMTLJSONAdapter JSONDictionaryFromModel:request] aws_removeNullValues];
        } else {
            networkingRequest.parameters = @{};
        }
        NSMutableDictionary *headers = [NSMutableDictionary new];
        headers[@"X-Amz-Target"] = [NSString stringWithFormat:@"%@.%@", targetPrefix, operationName];
        networkingRequest.headers = headers;
        networkingRequest.HTTPMethod = HTTPMethod;
        networkingRequest.requestSerializer = [[AWSJSONRequestSerializer alloc] initWithJSONDefinition:[[AWSCognitoIdentityProviderResources sharedInstance] JSONObject]
                                                                                            actionName:operationName];
        networkingRequest.responseSerializer = [[AWSCognitoIdentityProviderResponseSerializer alloc] initWithJSONDefinition:[[AWSCognitoIdentityProviderResources sharedInstance] JSONObject]
                                                                                                  actionName:operationName
                                                                                                 outputClass:outputClass];
        return [self.networking sendRequest:networkingRequest];
    }
}

#pragma mark - Service method

- (AWSTask<AWSCognitoIdentityProviderAddCustomAttributesResponse *> *)addCustomAttributes:(AWSCognitoIdentityProviderAddCustomAttributesRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"AddCustomAttributes"
                   outputClass:[AWSCognitoIdentityProviderAddCustomAttributesResponse class]];
}

- (void)addCustomAttributes:(AWSCognitoIdentityProviderAddCustomAttributesRequest *)request
          completionHandler:(void (^)(AWSCognitoIdentityProviderAddCustomAttributesResponse *response, NSError *error))completionHandler {
    [[self addCustomAttributes:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderAddCustomAttributesResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderAddCustomAttributesResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderAdminConfirmSignUpResponse *> *)adminConfirmSignUp:(AWSCognitoIdentityProviderAdminConfirmSignUpRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"AdminConfirmSignUp"
                   outputClass:[AWSCognitoIdentityProviderAdminConfirmSignUpResponse class]];
}

- (void)adminConfirmSignUp:(AWSCognitoIdentityProviderAdminConfirmSignUpRequest *)request
         completionHandler:(void (^)(AWSCognitoIdentityProviderAdminConfirmSignUpResponse *response, NSError *error))completionHandler {
    [[self adminConfirmSignUp:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderAdminConfirmSignUpResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderAdminConfirmSignUpResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask *)adminDeleteUser:(AWSCognitoIdentityProviderAdminDeleteUserRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"AdminDeleteUser"
                   outputClass:nil];
}

- (void)adminDeleteUser:(AWSCognitoIdentityProviderAdminDeleteUserRequest *)request
      completionHandler:(void (^)(NSError *error))completionHandler {
    [[self adminDeleteUser:request] continueWithBlock:^id _Nullable(AWSTask * _Nonnull task) {
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderAdminDeleteUserAttributesResponse *> *)adminDeleteUserAttributes:(AWSCognitoIdentityProviderAdminDeleteUserAttributesRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"AdminDeleteUserAttributes"
                   outputClass:[AWSCognitoIdentityProviderAdminDeleteUserAttributesResponse class]];
}

- (void)adminDeleteUserAttributes:(AWSCognitoIdentityProviderAdminDeleteUserAttributesRequest *)request
                completionHandler:(void (^)(AWSCognitoIdentityProviderAdminDeleteUserAttributesResponse *response, NSError *error))completionHandler {
    [[self adminDeleteUserAttributes:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderAdminDeleteUserAttributesResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderAdminDeleteUserAttributesResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderAdminDisableUserResponse *> *)adminDisableUser:(AWSCognitoIdentityProviderAdminDisableUserRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"AdminDisableUser"
                   outputClass:[AWSCognitoIdentityProviderAdminDisableUserResponse class]];
}

- (void)adminDisableUser:(AWSCognitoIdentityProviderAdminDisableUserRequest *)request
       completionHandler:(void (^)(AWSCognitoIdentityProviderAdminDisableUserResponse *response, NSError *error))completionHandler {
    [[self adminDisableUser:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderAdminDisableUserResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderAdminDisableUserResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderAdminEnableUserResponse *> *)adminEnableUser:(AWSCognitoIdentityProviderAdminEnableUserRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"AdminEnableUser"
                   outputClass:[AWSCognitoIdentityProviderAdminEnableUserResponse class]];
}

- (void)adminEnableUser:(AWSCognitoIdentityProviderAdminEnableUserRequest *)request
      completionHandler:(void (^)(AWSCognitoIdentityProviderAdminEnableUserResponse *response, NSError *error))completionHandler {
    [[self adminEnableUser:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderAdminEnableUserResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderAdminEnableUserResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderAdminGetUserResponse *> *)adminGetUser:(AWSCognitoIdentityProviderAdminGetUserRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"AdminGetUser"
                   outputClass:[AWSCognitoIdentityProviderAdminGetUserResponse class]];
}

- (void)adminGetUser:(AWSCognitoIdentityProviderAdminGetUserRequest *)request
   completionHandler:(void (^)(AWSCognitoIdentityProviderAdminGetUserResponse *response, NSError *error))completionHandler {
    [[self adminGetUser:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderAdminGetUserResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderAdminGetUserResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderAdminResetUserPasswordResponse *> *)adminResetUserPassword:(AWSCognitoIdentityProviderAdminResetUserPasswordRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"AdminResetUserPassword"
                   outputClass:[AWSCognitoIdentityProviderAdminResetUserPasswordResponse class]];
}

- (void)adminResetUserPassword:(AWSCognitoIdentityProviderAdminResetUserPasswordRequest *)request
             completionHandler:(void (^)(AWSCognitoIdentityProviderAdminResetUserPasswordResponse *response, NSError *error))completionHandler {
    [[self adminResetUserPassword:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderAdminResetUserPasswordResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderAdminResetUserPasswordResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderAdminSetUserSettingsResponse *> *)adminSetUserSettings:(AWSCognitoIdentityProviderAdminSetUserSettingsRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"AdminSetUserSettings"
                   outputClass:[AWSCognitoIdentityProviderAdminSetUserSettingsResponse class]];
}

- (void)adminSetUserSettings:(AWSCognitoIdentityProviderAdminSetUserSettingsRequest *)request
           completionHandler:(void (^)(AWSCognitoIdentityProviderAdminSetUserSettingsResponse *response, NSError *error))completionHandler {
    [[self adminSetUserSettings:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderAdminSetUserSettingsResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderAdminSetUserSettingsResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderAdminUpdateUserAttributesResponse *> *)adminUpdateUserAttributes:(AWSCognitoIdentityProviderAdminUpdateUserAttributesRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"AdminUpdateUserAttributes"
                   outputClass:[AWSCognitoIdentityProviderAdminUpdateUserAttributesResponse class]];
}

- (void)adminUpdateUserAttributes:(AWSCognitoIdentityProviderAdminUpdateUserAttributesRequest *)request
                completionHandler:(void (^)(AWSCognitoIdentityProviderAdminUpdateUserAttributesResponse *response, NSError *error))completionHandler {
    [[self adminUpdateUserAttributes:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderAdminUpdateUserAttributesResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderAdminUpdateUserAttributesResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderAuthenticateResponse *> *)authenticate:(AWSCognitoIdentityProviderAuthenticateRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"Authenticate"
                   outputClass:[AWSCognitoIdentityProviderAuthenticateResponse class]];
}

- (void)authenticate:(AWSCognitoIdentityProviderAuthenticateRequest *)request
   completionHandler:(void (^)(AWSCognitoIdentityProviderAuthenticateResponse *response, NSError *error))completionHandler {
    [[self authenticate:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderAuthenticateResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderAuthenticateResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderChangePasswordResponse *> *)changePassword:(AWSCognitoIdentityProviderChangePasswordRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"ChangePassword"
                   outputClass:[AWSCognitoIdentityProviderChangePasswordResponse class]];
}

- (void)changePassword:(AWSCognitoIdentityProviderChangePasswordRequest *)request
     completionHandler:(void (^)(AWSCognitoIdentityProviderChangePasswordResponse *response, NSError *error))completionHandler {
    [[self changePassword:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderChangePasswordResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderChangePasswordResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderConfirmForgotPasswordResponse *> *)confirmForgotPassword:(AWSCognitoIdentityProviderConfirmForgotPasswordRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"ConfirmForgotPassword"
                   outputClass:[AWSCognitoIdentityProviderConfirmForgotPasswordResponse class]];
}

- (void)confirmForgotPassword:(AWSCognitoIdentityProviderConfirmForgotPasswordRequest *)request
            completionHandler:(void (^)(AWSCognitoIdentityProviderConfirmForgotPasswordResponse *response, NSError *error))completionHandler {
    [[self confirmForgotPassword:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderConfirmForgotPasswordResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderConfirmForgotPasswordResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderConfirmSignUpResponse *> *)confirmSignUp:(AWSCognitoIdentityProviderConfirmSignUpRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"ConfirmSignUp"
                   outputClass:[AWSCognitoIdentityProviderConfirmSignUpResponse class]];
}

- (void)confirmSignUp:(AWSCognitoIdentityProviderConfirmSignUpRequest *)request
    completionHandler:(void (^)(AWSCognitoIdentityProviderConfirmSignUpResponse *response, NSError *error))completionHandler {
    [[self confirmSignUp:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderConfirmSignUpResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderConfirmSignUpResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderCreateUserPoolResponse *> *)createUserPool:(AWSCognitoIdentityProviderCreateUserPoolRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"CreateUserPool"
                   outputClass:[AWSCognitoIdentityProviderCreateUserPoolResponse class]];
}

- (void)createUserPool:(AWSCognitoIdentityProviderCreateUserPoolRequest *)request
     completionHandler:(void (^)(AWSCognitoIdentityProviderCreateUserPoolResponse *response, NSError *error))completionHandler {
    [[self createUserPool:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderCreateUserPoolResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderCreateUserPoolResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderCreateUserPoolClientResponse *> *)createUserPoolClient:(AWSCognitoIdentityProviderCreateUserPoolClientRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"CreateUserPoolClient"
                   outputClass:[AWSCognitoIdentityProviderCreateUserPoolClientResponse class]];
}

- (void)createUserPoolClient:(AWSCognitoIdentityProviderCreateUserPoolClientRequest *)request
           completionHandler:(void (^)(AWSCognitoIdentityProviderCreateUserPoolClientResponse *response, NSError *error))completionHandler {
    [[self createUserPoolClient:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderCreateUserPoolClientResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderCreateUserPoolClientResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask *)deleteUser:(AWSCognitoIdentityProviderDeleteUserRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"DeleteUser"
                   outputClass:nil];
}

- (void)deleteUser:(AWSCognitoIdentityProviderDeleteUserRequest *)request
 completionHandler:(void (^)(NSError *error))completionHandler {
    [[self deleteUser:request] continueWithBlock:^id _Nullable(AWSTask * _Nonnull task) {
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderDeleteUserAttributesResponse *> *)deleteUserAttributes:(AWSCognitoIdentityProviderDeleteUserAttributesRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"DeleteUserAttributes"
                   outputClass:[AWSCognitoIdentityProviderDeleteUserAttributesResponse class]];
}

- (void)deleteUserAttributes:(AWSCognitoIdentityProviderDeleteUserAttributesRequest *)request
           completionHandler:(void (^)(AWSCognitoIdentityProviderDeleteUserAttributesResponse *response, NSError *error))completionHandler {
    [[self deleteUserAttributes:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderDeleteUserAttributesResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderDeleteUserAttributesResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask *)deleteUserPool:(AWSCognitoIdentityProviderDeleteUserPoolRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"DeleteUserPool"
                   outputClass:nil];
}

- (void)deleteUserPool:(AWSCognitoIdentityProviderDeleteUserPoolRequest *)request
     completionHandler:(void (^)(NSError *error))completionHandler {
    [[self deleteUserPool:request] continueWithBlock:^id _Nullable(AWSTask * _Nonnull task) {
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(error);
        }
        
        return nil;
    }];
}

- (AWSTask *)deleteUserPoolClient:(AWSCognitoIdentityProviderDeleteUserPoolClientRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"DeleteUserPoolClient"
                   outputClass:nil];
}

- (void)deleteUserPoolClient:(AWSCognitoIdentityProviderDeleteUserPoolClientRequest *)request
           completionHandler:(void (^)(NSError *error))completionHandler {
    [[self deleteUserPoolClient:request] continueWithBlock:^id _Nullable(AWSTask * _Nonnull task) {
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderDescribeUserPoolResponse *> *)describeUserPool:(AWSCognitoIdentityProviderDescribeUserPoolRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"DescribeUserPool"
                   outputClass:[AWSCognitoIdentityProviderDescribeUserPoolResponse class]];
}

- (void)describeUserPool:(AWSCognitoIdentityProviderDescribeUserPoolRequest *)request
       completionHandler:(void (^)(AWSCognitoIdentityProviderDescribeUserPoolResponse *response, NSError *error))completionHandler {
    [[self describeUserPool:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderDescribeUserPoolResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderDescribeUserPoolResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderDescribeUserPoolClientResponse *> *)describeUserPoolClient:(AWSCognitoIdentityProviderDescribeUserPoolClientRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"DescribeUserPoolClient"
                   outputClass:[AWSCognitoIdentityProviderDescribeUserPoolClientResponse class]];
}

- (void)describeUserPoolClient:(AWSCognitoIdentityProviderDescribeUserPoolClientRequest *)request
             completionHandler:(void (^)(AWSCognitoIdentityProviderDescribeUserPoolClientResponse *response, NSError *error))completionHandler {
    [[self describeUserPoolClient:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderDescribeUserPoolClientResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderDescribeUserPoolClientResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderEnhanceAuthResponse *> *)enhanceAuth:(AWSCognitoIdentityProviderEnhanceAuthRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"EnhanceAuth"
                   outputClass:[AWSCognitoIdentityProviderEnhanceAuthResponse class]];
}

- (void)enhanceAuth:(AWSCognitoIdentityProviderEnhanceAuthRequest *)request
  completionHandler:(void (^)(AWSCognitoIdentityProviderEnhanceAuthResponse *response, NSError *error))completionHandler {
    [[self enhanceAuth:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderEnhanceAuthResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderEnhanceAuthResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderForgotPasswordResponse *> *)forgotPassword:(AWSCognitoIdentityProviderForgotPasswordRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"ForgotPassword"
                   outputClass:[AWSCognitoIdentityProviderForgotPasswordResponse class]];
}

- (void)forgotPassword:(AWSCognitoIdentityProviderForgotPasswordRequest *)request
     completionHandler:(void (^)(AWSCognitoIdentityProviderForgotPasswordResponse *response, NSError *error))completionHandler {
    [[self forgotPassword:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderForgotPasswordResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderForgotPasswordResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderGetAuthenticationDetailsResponse *> *)getAuthenticationDetails:(AWSCognitoIdentityProviderGetAuthenticationDetailsRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"GetAuthenticationDetails"
                   outputClass:[AWSCognitoIdentityProviderGetAuthenticationDetailsResponse class]];
}

- (void)getAuthenticationDetails:(AWSCognitoIdentityProviderGetAuthenticationDetailsRequest *)request
               completionHandler:(void (^)(AWSCognitoIdentityProviderGetAuthenticationDetailsResponse *response, NSError *error))completionHandler {
    [[self getAuthenticationDetails:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderGetAuthenticationDetailsResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderGetAuthenticationDetailsResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderGetJWKSResponse *> *)getJWKS:(AWSCognitoIdentityProviderGetJWKSRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodGET
                     URLString:@"/{userPoolId}/.well-known/jwks.json"
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"GetJWKS"
                   outputClass:[AWSCognitoIdentityProviderGetJWKSResponse class]];
}

- (void)getJWKS:(AWSCognitoIdentityProviderGetJWKSRequest *)request
completionHandler:(void (^)(AWSCognitoIdentityProviderGetJWKSResponse *response, NSError *error))completionHandler {
    [[self getJWKS:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderGetJWKSResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderGetJWKSResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderGetOpenIdConfigurationResponse *> *)getOpenIdConfiguration:(AWSCognitoIdentityProviderGetOpenIdConfigurationRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodGET
                     URLString:@"/{userPoolId}/.well-known/openid-configuration"
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"GetOpenIdConfiguration"
                   outputClass:[AWSCognitoIdentityProviderGetOpenIdConfigurationResponse class]];
}

- (void)getOpenIdConfiguration:(AWSCognitoIdentityProviderGetOpenIdConfigurationRequest *)request
             completionHandler:(void (^)(AWSCognitoIdentityProviderGetOpenIdConfigurationResponse *response, NSError *error))completionHandler {
    [[self getOpenIdConfiguration:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderGetOpenIdConfigurationResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderGetOpenIdConfigurationResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderGetUserResponse *> *)getUser:(AWSCognitoIdentityProviderGetUserRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"GetUser"
                   outputClass:[AWSCognitoIdentityProviderGetUserResponse class]];
}

- (void)getUser:(AWSCognitoIdentityProviderGetUserRequest *)request
completionHandler:(void (^)(AWSCognitoIdentityProviderGetUserResponse *response, NSError *error))completionHandler {
    [[self getUser:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderGetUserResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderGetUserResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderGetUserAttributeVerificationCodeResponse *> *)getUserAttributeVerificationCode:(AWSCognitoIdentityProviderGetUserAttributeVerificationCodeRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"GetUserAttributeVerificationCode"
                   outputClass:[AWSCognitoIdentityProviderGetUserAttributeVerificationCodeResponse class]];
}

- (void)getUserAttributeVerificationCode:(AWSCognitoIdentityProviderGetUserAttributeVerificationCodeRequest *)request
                       completionHandler:(void (^)(AWSCognitoIdentityProviderGetUserAttributeVerificationCodeResponse *response, NSError *error))completionHandler {
    [[self getUserAttributeVerificationCode:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderGetUserAttributeVerificationCodeResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderGetUserAttributeVerificationCodeResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderListUserPoolClientsResponse *> *)listUserPoolClients:(AWSCognitoIdentityProviderListUserPoolClientsRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"ListUserPoolClients"
                   outputClass:[AWSCognitoIdentityProviderListUserPoolClientsResponse class]];
}

- (void)listUserPoolClients:(AWSCognitoIdentityProviderListUserPoolClientsRequest *)request
          completionHandler:(void (^)(AWSCognitoIdentityProviderListUserPoolClientsResponse *response, NSError *error))completionHandler {
    [[self listUserPoolClients:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderListUserPoolClientsResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderListUserPoolClientsResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderListUserPoolsResponse *> *)listUserPools:(AWSCognitoIdentityProviderListUserPoolsRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"ListUserPools"
                   outputClass:[AWSCognitoIdentityProviderListUserPoolsResponse class]];
}

- (void)listUserPools:(AWSCognitoIdentityProviderListUserPoolsRequest *)request
    completionHandler:(void (^)(AWSCognitoIdentityProviderListUserPoolsResponse *response, NSError *error))completionHandler {
    [[self listUserPools:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderListUserPoolsResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderListUserPoolsResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderListUsersResponse *> *)listUsers:(AWSCognitoIdentityProviderListUsersRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"ListUsers"
                   outputClass:[AWSCognitoIdentityProviderListUsersResponse class]];
}

- (void)listUsers:(AWSCognitoIdentityProviderListUsersRequest *)request
completionHandler:(void (^)(AWSCognitoIdentityProviderListUsersResponse *response, NSError *error))completionHandler {
    [[self listUsers:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderListUsersResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderListUsersResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderRefreshTokensResponse *> *)refreshTokens:(AWSCognitoIdentityProviderRefreshTokensRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"RefreshTokens"
                   outputClass:[AWSCognitoIdentityProviderRefreshTokensResponse class]];
}

- (void)refreshTokens:(AWSCognitoIdentityProviderRefreshTokensRequest *)request
    completionHandler:(void (^)(AWSCognitoIdentityProviderRefreshTokensResponse *response, NSError *error))completionHandler {
    [[self refreshTokens:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderRefreshTokensResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderRefreshTokensResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderResendConfirmationCodeResponse *> *)resendConfirmationCode:(AWSCognitoIdentityProviderResendConfirmationCodeRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"ResendConfirmationCode"
                   outputClass:[AWSCognitoIdentityProviderResendConfirmationCodeResponse class]];
}

- (void)resendConfirmationCode:(AWSCognitoIdentityProviderResendConfirmationCodeRequest *)request
             completionHandler:(void (^)(AWSCognitoIdentityProviderResendConfirmationCodeResponse *response, NSError *error))completionHandler {
    [[self resendConfirmationCode:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderResendConfirmationCodeResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderResendConfirmationCodeResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderSetUserSettingsResponse *> *)setUserSettings:(AWSCognitoIdentityProviderSetUserSettingsRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"SetUserSettings"
                   outputClass:[AWSCognitoIdentityProviderSetUserSettingsResponse class]];
}

- (void)setUserSettings:(AWSCognitoIdentityProviderSetUserSettingsRequest *)request
      completionHandler:(void (^)(AWSCognitoIdentityProviderSetUserSettingsResponse *response, NSError *error))completionHandler {
    [[self setUserSettings:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderSetUserSettingsResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderSetUserSettingsResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderSignUpResponse *> *)signUp:(AWSCognitoIdentityProviderSignUpRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"SignUp"
                   outputClass:[AWSCognitoIdentityProviderSignUpResponse class]];
}

- (void)signUp:(AWSCognitoIdentityProviderSignUpRequest *)request
completionHandler:(void (^)(AWSCognitoIdentityProviderSignUpResponse *response, NSError *error))completionHandler {
    [[self signUp:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderSignUpResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderSignUpResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderUpdateUserAttributesResponse *> *)updateUserAttributes:(AWSCognitoIdentityProviderUpdateUserAttributesRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"UpdateUserAttributes"
                   outputClass:[AWSCognitoIdentityProviderUpdateUserAttributesResponse class]];
}

- (void)updateUserAttributes:(AWSCognitoIdentityProviderUpdateUserAttributesRequest *)request
           completionHandler:(void (^)(AWSCognitoIdentityProviderUpdateUserAttributesResponse *response, NSError *error))completionHandler {
    [[self updateUserAttributes:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderUpdateUserAttributesResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderUpdateUserAttributesResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderUpdateUserPoolResponse *> *)updateUserPool:(AWSCognitoIdentityProviderUpdateUserPoolRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"UpdateUserPool"
                   outputClass:[AWSCognitoIdentityProviderUpdateUserPoolResponse class]];
}

- (void)updateUserPool:(AWSCognitoIdentityProviderUpdateUserPoolRequest *)request
     completionHandler:(void (^)(AWSCognitoIdentityProviderUpdateUserPoolResponse *response, NSError *error))completionHandler {
    [[self updateUserPool:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderUpdateUserPoolResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderUpdateUserPoolResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderUpdateUserPoolClientResponse *> *)updateUserPoolClient:(AWSCognitoIdentityProviderUpdateUserPoolClientRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"UpdateUserPoolClient"
                   outputClass:[AWSCognitoIdentityProviderUpdateUserPoolClientResponse class]];
}

- (void)updateUserPoolClient:(AWSCognitoIdentityProviderUpdateUserPoolClientRequest *)request
           completionHandler:(void (^)(AWSCognitoIdentityProviderUpdateUserPoolClientResponse *response, NSError *error))completionHandler {
    [[self updateUserPoolClient:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderUpdateUserPoolClientResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderUpdateUserPoolClientResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

- (AWSTask<AWSCognitoIdentityProviderVerifyUserAttributeResponse *> *)verifyUserAttribute:(AWSCognitoIdentityProviderVerifyUserAttributeRequest *)request {
    return [self invokeRequest:request
                    HTTPMethod:AWSHTTPMethodPOST
                     URLString:@""
                  targetPrefix:@"AWSCognitoIdentityProviderService"
                 operationName:@"VerifyUserAttribute"
                   outputClass:[AWSCognitoIdentityProviderVerifyUserAttributeResponse class]];
}

- (void)verifyUserAttribute:(AWSCognitoIdentityProviderVerifyUserAttributeRequest *)request
          completionHandler:(void (^)(AWSCognitoIdentityProviderVerifyUserAttributeResponse *response, NSError *error))completionHandler {
    [[self verifyUserAttribute:request] continueWithBlock:^id _Nullable(AWSTask<AWSCognitoIdentityProviderVerifyUserAttributeResponse *> * _Nonnull task) {
        AWSCognitoIdentityProviderVerifyUserAttributeResponse *result = task.result;
        NSError *error = task.error;
        
        if (task.exception) {
            AWSLogError(@"Fatal exception: [%@]", task.exception);
            kill(getpid(), SIGKILL);
        }
        
        if (completionHandler) {
            completionHandler(result, error);
        }
        
        return nil;
    }];
}

@end
