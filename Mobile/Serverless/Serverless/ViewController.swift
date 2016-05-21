//
//  ViewController.swift
//  Serverless
//
//  Created by 寺井 大樹 on 2016/05/12.
//  Copyright © 2016年 寺井 大樹. All rights reserved.
//

import UIKit

class ViewController: UIViewController,UITextFieldDelegate {

    //////////////////////
    // Config Param
    //////////////////////
    
    var UserPoolId = "us-east-1_<Pool Id>" // Cognito User Pool Id
    var ClientId = "<Client Id>" // Cognito User Pool Client Id
    var ClientSecret = "<Client Secret>" // Cognito User Pool Client Secret
    var IdentitityPoolId = "us-east-1:<Identity Pool Id>" // Cognito Identity Pool Id
    let EndPoint = "https://<API>.execute-api.us-east-1.amazonaws.com/<Stage>" // API Gateway Endpoint
    let API = "/<API>" // API Gateway API
    
    //////////////////////

    
    // Cognito User Pool
    var pool: AWSCognitoIdentityUserPool?
    
    @IBOutlet weak var signupName: UITextField!
    @IBOutlet weak var signupPassword: UITextField!
    @IBOutlet weak var signupEmail: UITextField!
    
    @IBOutlet weak var verifyName: UITextField!
    @IBOutlet weak var verifyCode: UITextField!
    
    @IBOutlet weak var loginName: UITextField!
    @IBOutlet weak var loginPassword: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        

        
        let configuration: AWSServiceConfiguration = AWSServiceConfiguration(region: .USEast1, credentialsProvider: nil)
        AWSServiceManager.defaultServiceManager().defaultServiceConfiguration = configuration
        
        let userPoolConfigration: AWSCognitoIdentityUserPoolConfiguration =
            AWSCognitoIdentityUserPoolConfiguration(clientId: ClientId, clientSecret: ClientSecret, poolId: UserPoolId)
        
        // 名前をつけておくことで、このプールのインスタンスを取得することができます
        let PoolKey = "AmazonCognitoIdentityProvider"
        AWSCognitoIdentityUserPool.registerCognitoIdentityUserPoolWithUserPoolConfiguration(userPoolConfigration, forKey: PoolKey)
        pool = AWSCognitoIdentityUserPool(forKey: PoolKey)
        
        
        signupName.delegate = self
        signupPassword.delegate = self
        signupEmail.delegate = self
        verifyName.delegate = self
        verifyCode.delegate = self
        loginName.delegate = self
        loginPassword.delegate = self
        
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    

    @IBAction func SignUp(sender: AnyObject) {
        
        // Sign Up
        let email: AWSCognitoIdentityUserAttributeType = AWSCognitoIdentityUserAttributeType()
        email.name = "email"
        email.value = signupEmail.text!
        
        pool!.signUp(self.signupName.text!, password: self.signupPassword.text!, userAttributes: [email], validationData: nil).continueWithBlock({ task in
            if((task.error) != nil) {
                print(task.error?.code)
            } else {
                print(task.result)
                
                dispatch_async(dispatch_get_main_queue(), {
                    self.verifyName.text = self.signupName.text
                    
                })
            }
            return nil
        })
        
    }
    
    

    
    @IBAction func Verify(sender: AnyObject) {
        
        let user: AWSCognitoIdentityUser = pool!.getUser(self.verifyName.text!)
        
        user.confirmSignUp(self.verifyCode.text!).continueWithBlock({ task in
            if((task.error) != nil) {
                print(task.error?.code)
            } else {
                print(task.result)
                
                dispatch_async(dispatch_get_main_queue(), {
                    self.loginName.text = self.verifyName.text
                    self.loginPassword.text = self.signupPassword.text
                })
                
            }
            return nil
        })

    }
    
    
    
    @IBAction func Login(sender: AnyObject) {
        
        
        let user: AWSCognitoIdentityUser = pool!.getUser(self.loginName.text!)
        
        
        user.getSession(self.loginName.text!, password: self.loginPassword.text!, validationData: nil, scopes: nil).continueWithBlock({task in
            if((task.error) != nil) {
                print(task.error)
            } else {
                print(task.result)
                
                let cognitoIdentityPoolId = self.IdentitityPoolId
                let ret = task.result as! AWSCognitoIdentityUserSession
                let IdToken : String =  ret.idToken!.tokenString
                
                // 認証プロバイダーにUser Poolを使う
                let provider = "cognito-idp.us-east-1.amazonaws.com/" + self.UserPoolId
                
                let userpoolProvider = UserPoolProvider()
                userpoolProvider.setting(provider, token: IdToken)
                let credentialsProvider = AWSCognitoCredentialsProvider(
                    regionType: .USEast1,
                    identityPoolId: cognitoIdentityPoolId,
                    identityProviderManager: userpoolProvider
                )
                // credentialのキャッシュをクリア
                credentialsProvider.clearKeychain()
                
                
                // credential取得
                credentialsProvider.credentials().continueWithBlock { (task: AWSTask!) -> AnyObject! in
                    
                    if (task.error != nil) {
                        print(task.error)
                        
                    } else {
                        print(task.result)


                        self.callAPI(credentialsProvider)
 
                        
                    }
                    return nil
                }

                
                
            }
            
            return nil
        })
        
    }
    
    func callAPI(credentialsProvider:AWSCognitoCredentialsProvider){
        
        // API Gatewayのエンドポイント設定
        ServerlessClient.setEndPoint(EndPoint)
        
        // Cognito identityPoolIdによるAPI認可
        let configuration = AWSServiceConfiguration(region: .USEast1, credentialsProvider: credentialsProvider)
        ServerlessClient.registerClientWithConfiguration(configuration,forKey: "Auth")
    
        
        
        
        ///////////////////////API認可されたAPIの呼び出し///////////////////////////
        
        
        let client = ServerlessClient(forKey: "Auth")
        
        client.Post(API,param: ["":""]).continueWithBlock { (task: AWSTask!) -> AnyObject! in
            
            if (task.error != nil) {
                print(task.error)
                
            } else {
                print(task.result)
                
            }
            return nil
        }
        
    }
    
    


    
    func textFieldShouldReturn(textField: UITextField) -> Bool{
        
        // キーボードを閉じる
        textField.resignFirstResponder()
        
        return true
    }
    
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        
    }


}

