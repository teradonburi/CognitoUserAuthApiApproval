//
//  UserPool.swift
//  Serverless
//
//  Created by 寺井 大樹 on 2016/05/17.
//  Copyright © 2016年 寺井 大樹. All rights reserved.
//

import Foundation

public class UserPoolProvider:NSObject, AWSIdentityProviderManager{
    
    var providerName:String!
    var token:String!
    
    public func setting(providerName:String,token:String){
        self.providerName = providerName
        self.token = token
    }
    
    public func logins() -> AWSTask {
        var providers = [String:String]()
        providers[self.providerName] = self.token
        return AWSTask(result: providers as AnyObject)
    }
}