#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// 伪造的响应数据
static NSString* getFakeResponse(NSString *url) {
    if ([url containsString:@"sync_data"]) {
        return @"{\"code\":0,\"msg\":\"success\"}";
    }
    if ([url containsString:@"version.txt"] || [url containsString:@"switch.txt"]) {
        return @"{\"code\":0,\"msg\":\"success\"}";
    }
    if ([url containsString:@"send_bind_phone_login_code"]) {
        return @"{\"status\":0,\"msg\":\"success\",\"data\":{}}";
    }
    if ([url containsString:@"code_login_v2.do"]) {
        return [NSString stringWithFormat:
            @"{\"status\":0,\"msg\":\"success\",\"data\":{"
            "\"token\":\"fake_token_%@\","
            "\"userId\":\"100000001\","
            "\"nickname\":\"弹射勇士\","
            "\"sessionId\":\"fake_session_%@\","
            "\"loginTime\":%ld,"
            "\"pfKey\":\"wf_ios_210009\","
            "\"isRegister\":0,"
            "\"bind\":1,"
            "\"sessionType\":1"
            "}}",
            [[NSUUID UUID] UUIDString],
            [[NSUUID UUID] UUIDString],
            (long)([[NSDate date] timeIntervalSince1970] * 1000)
        ];
    }
    if ([url containsString:@"skan"] || [url containsString:@"advert"]) {
        return @"{\"status\":0,\"data\":null}";
    }
    if ([url containsString:@"sdklog"] || [url containsString:@"report"] || [url containsString:@"heartbeat"]) {
        return @"{\"code\":0}";
    }
    if ([url containsString:@"config.json"]) {
        return @"{\"status\":0,\"msg\":\"success\"}";
    }
    if ([url containsString:@"myip"]) {
        return @"{\"ip\":\"127.0.0.1\",\"country\":\"CN\"}";
    }
    return nil;
}

// ============ NSURLProtocol 拦截 ============

@interface LeitingBypassProtocol : NSURLProtocol
@end

@implementation LeitingBypassProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    NSString *url = request.URL.absoluteString;
    if ([url containsString:@"leiting.com"] || [url containsString:@"roguelike.com"]) {
        if (getFakeResponse(url)) {
            NSLog(@"[Bypass] 拦截: %@", url);
            return YES;
        }
    }
    return NO;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    NSString *url = self.request.URL.absoluteString;
    NSString *fakeBody = getFakeResponse(url) ?: @"{\"code\":0,\"msg\":\"success\"}";
    NSLog(@"[Bypass] 返回: %@", url);
    
    NSData *data = [fakeBody dataUsingEncoding:NSUTF8StringEncoding];
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc]
        initWithURL:self.request.URL
        statusCode:200
        HTTPVersion:@"HTTP/1.1"
        headerFields:@{@"Content-Type": @"application/json"}];
    
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowed];
    [self.client URLProtocol:self didLoadData:data];
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)stopLoading {}

@end

// ============ Hook NSURLSession ============

static void (*orig_dataTaskWithRequest)(id, SEL, id, id);

void hook_dataTaskWithRequest(id self, SEL _cmd, NSURLRequest *request, void (^completionHandler)(NSData *, NSURLResponse *, NSError *)) {
    NSString *url = request.URL.absoluteString;
    
    if ([url containsString:@"leiting.com"] || [url containsString:@"roguelike.com"]) {
        NSString *fakeBody = getFakeResponse(url);
        if (fakeBody) {
            NSLog(@"[Bypass Hook] 拦截: %@", url);
            NSData *data = [fakeBody dataUsingEncoding:NSUTF8StringEncoding];
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc]
                initWithURL:request.URL
                statusCode:200
                HTTPVersion:@"HTTP/1.1"
                headerFields:@{}];
            if (completionHandler) {
                completionHandler(data, response, nil);
            }
            return;
        }
    }
    
    orig_dataTaskWithRequest(self, _cmd, request, completionHandler);
}

// ============ isRealSDK 修改 ============

static void patch_isRealSDK(void) {
    int classCount = objc_getClassList(NULL, 0);
    Class *classes = (Class *)malloc(sizeof(Class) * classCount);
    objc_getClassList(classes, classCount);
    
    for (int i = 0; i < classCount; i++) {
        Class cls = classes[i];
        const char *name = class_getName(cls);
        
        if (strstr(name, "SDK") || strstr(name, "Channel") || strstr(name, "sdk") || strstr(name, "channel")) {
            Method method = class_getInstanceMethod(cls, NSSelectorFromString(@"isRealSDK"));
            if (method) {
                NSLog(@"[Bypass] 找到 isRealSDK 在 %s，修改为返回 YES", name);
                IMP newImp = imp_implementationWithBlock(^BOOL(id self) {
                    return YES;
                });
                method_setImplementation(method, newImp);
            }
        }
    }
    
    free(classes);
}

// ============ 构造函数 ============

__attribute__((constructor))
static void init() {
    NSLog(@"[Bypass] dylib 已加载");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSURLProtocol registerClass:[LeitingBypassProtocol class]];
        NSLog(@"[Bypass] NSURLProtocol 已注册");
        
        Class sessionClass = [NSURLSession class];
        SEL sel = @selector(dataTaskWithRequest:completionHandler:);
        Method method = class_getInstanceMethod(sessionClass, sel);
        if (method) {
            orig_dataTaskWithRequest = (void *)method_getImplementation(method);
            method_setImplementation(method, (IMP)hook_dataTaskWithRequest);
            NSLog(@"[Bypass] NSURLSession Hook 成功");
        }
        
        patch_isRealSDK();
        NSLog(@"[Bypass] 初始化完成");
    });
}
