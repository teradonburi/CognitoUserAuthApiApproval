# AWS Cognitoでのユーザ認証＆API認可サンプル
Cognito User Poolによるユーザ登録・ユーザ認証  
認証ユーザに対してのSTSによるAPI GatewayのAPI認可のサンプル

* ブラウザ（Javascript）
* iOS
* Android


## 概要

下記AWSサービスを用いてサーバレス（認証サーバ、アプリケーションサーバ無し）で  
ユーザ認証と認証ユーザに対し、認可APIを提供するサンプルです。

* Cognito 
* IAM
* API Gateway
* Lambda

## 動作確認

下記環境で動作確認しました

* Google Chorme (version 50)
* iOS 9以上
* Android 5以上

## 使い道

* Cognito User Poolに認証ユーザ情報を一元管理
* 認証ユーザに対し、 Cognito Federated IdentityでIdentity Pool別に割り当てたIAMでサービス別にAPI認可ができる

## 導入方法

AWS側の設定およびサンプルの設定は下記参考  
[世界に先駆けてAWSサーバレスアーキテクチャでユーザ認証とAPI認可の実装をしてみた](http://qiita.com/teradonburi/items/ef535d19c28a009552ec)


## ライセンス

AWS SDKライブラリの方はAmazonさん準拠になります。  
サンプルの方はMIT  
（改変、商用利用など、ご自由に）

## 作者

[teradonburi](https://github.com/teradonburi)