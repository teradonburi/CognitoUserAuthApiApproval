//
// Source code recreated from a .class file by IntelliJ IDEA
// (powered by Fernflower decompiler)
//

package com.example.teraidaiki.serverless;

import com.amazonaws.mobileconnectors.apigateway.annotation.Operation;
import com.amazonaws.mobileconnectors.apigateway.annotation.Service;

@Service(
        endpoint = "https://<API Gateway Stage Id>.execute-api.us-east-1.amazonaws.com/test"
)
public interface TestClient {
    @Operation(
            path = "/test",
            method = "POST"
    )
    ResponseData testPost(String param);

}
