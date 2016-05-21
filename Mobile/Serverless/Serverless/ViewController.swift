//
//  ViewController.swift
//  Serverless
//
//  Created by 寺井 大樹 on 2016/05/12.
//  Copyright © 2016年 寺井 大樹. All rights reserved.
//

import UIKit

class ViewController: UIViewController,UITextFieldDelegate {

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
            AWSCognitoIdentityUserPoolConfiguration(clientId: "1iq0nruq3ehrk5rmdutsqvbnjk", clientSecret: "1409e4527acgn21jsiu429m9k5njs9n1g6v3kmg3o791ifr0lstf", poolId: "us-east-1_Fidg1SRpL")
        
        // 名前をつけておくことで、このプールのインスタンスを取得することができます
        AWSCognitoIdentityUserPool.registerCognitoIdentityUserPoolWithUserPoolConfiguration(userPoolConfigration, forKey: "AmazonCognitoIdentityProvider")
        
        pool = AWSCognitoIdentityUserPool(forKey: "AmazonCognitoIdentityProvider")
        
        
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
                
                let cognitoIdentityPoolId = "us-east-1:41bbf911-3f5e-4ba0-acfe-bd71eaa7f8b3"
                let ret = task.result as! AWSCognitoIdentityUserSession
                let IdToken : String =  ret.idToken!.tokenString
                
                let userpoolProvider = UserPoolProvider()
                userpoolProvider.setting("cognito-idp.us-east-1.amazonaws.com/us-east-1_Fidg1SRpL", token: IdToken)
                let credentialsProvider = AWSCognitoCredentialsProvider(
                    regionType: .USEast1,
                    identityPoolId: cognitoIdentityPoolId,
                    identityProviderManager: userpoolProvider
                )
                let configuration = AWSServiceConfiguration(region:.APNortheast1, credentialsProvider:credentialsProvider)
                AWSServiceManager.defaultServiceManager().defaultServiceConfiguration = configuration
                
                
                // credential取得
                credentialsProvider.credentials().continueWithBlock { (task: AWSTask!) -> AnyObject! in
                    
                    if (task.error != nil) {
                        print(task.error)
                        
                    } else {
                        print(task.result)


                        
                        credentialsProvider.getIdentityId().continueWithBlock { (task: AWSTask!) -> AnyObject! in
                            
                            if (task.error != nil) {
                                print(task.error)
                                
                            } else {
                                
                                // identityId
                                let identityId = task.result as! String
                                print(identityId)
                                
                                let cognitoIdentity = AWSCognitoIdentity.defaultCognitoIdentity()
                                let input = AWSCognitoIdentityGetCredentialsForIdentityInput()
                                input.identityId = identityId
                                input.logins = [
                                    "cognito-idp.us-east-1.amazonaws.com/us-east-1_Fidg1SRpL": IdToken
                                ]
                                
                                cognitoIdentity.getCredentialsForIdentity(input).continueWithBlock { (task: AWSTask!) -> AnyObject! in
                                    
                                    if (task.error != nil) {
                                        print(task.error)
                                        
                                    } else {
                                        print(task.result)
                                        
                                        
                                        self.callAPI(credentialsProvider,identityId: identityId)

                                    }
                                    
                                    return nil
                                }
                               
                                

                                
                            }
                            return nil
                        }
 
                        
                    }
                    return nil
                }

                
                
            }
            
            return nil
        })
        
    }
    
    func callAPI(credentialsProvider:AWSCognitoCredentialsProvider,identityId:String){
        
        // API Gatewayのエンドポイント設定
        ServerlessClient.setEndPoint("https://s8ls7wv8di.execute-api.us-east-1.amazonaws.com/test")
        
        // Cognito identityPoolIdによるAPI認可
        let configuration = AWSServiceConfiguration(region: .USEast1, credentialsProvider: credentialsProvider)
        ServerlessClient.registerClientWithConfiguration(configuration,forKey: "Auth")
    
        
        
        
        ///////////////////////API認可されたAPIの呼び出し///////////////////////////
        
        
        let client = ServerlessClient(forKey: "Auth")
        
        client.Post("/test",param: ["key1":"abc"]).continueWithBlock { (task: AWSTask!) -> AnyObject! in
            
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

