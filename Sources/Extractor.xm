#import "Extractor.h"

@implementation YouTubeExtractor

+ (NSDictionary *)youtubePlayerRequest :(NSString *)clientId :(NSString *)videoId {
    if (!videoId.length) return nil;
    NSLocale *locale = [NSLocale currentLocale];
	NSString *countryCode = [locale objectForKey:NSLocaleCountryCode] ?: @"US";

    NSString *innertubeKey = nil;
    NSString *jsonBody = nil;
    if ([clientId isEqual:@"mediaconnect"]) {
        innertubeKey = @"AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w";
        jsonBody = [NSString stringWithFormat:@"{\"context\":{\"client\":{\"hl\":\"en\",\"gl\":\"%@\",\"clientName\":\"MEDIA_CONNECT_FRONTEND\",\"clientVersion\":\"0.1\"}},\"contentCheckOk\":true,\"racyCheckOk\":true,\"videoId\":\"%@\"}", countryCode, videoId];
    }
    if ([clientId isEqual:@"ios"]) {
        // Was "AAIzaSy…" (doubled leading A): an invalid key, so every "ios"
        // request was rejected by the server.
        innertubeKey = @"AIzaSyB-63vPrdThhKuerbB2N_l7Kwwcxj6yUAc";
        jsonBody = [NSString stringWithFormat:@"{\"context\":{\"client\":{\"hl\":\"en\",\"gl\":\"%@\",\"clientName\":\"IOS\",\"clientVersion\":\"19.09.3\",\"deviceModel\":\"iPhone14,3\"}},\"contentCheckOk\":true,\"racyCheckOk\":true,\"videoId\":\"%@\"}", countryCode, videoId];
    }
    if (!innertubeKey || !jsonBody) return nil; // unknown client id

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://www.youtube.com/youtubei/v1/player?key=%@&prettyPrint=false", innertubeKey]]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:[jsonBody dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES]];
    request.timeoutInterval = 20.0;

    // Semaphore with a timeout instead of an unbounded sleep-poll loop, and no
    // JSON parse of nil data (JSONObjectWithData:nil throws -> crash).
    __block NSData *requestData = nil;
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        requestData = data;
        dispatch_semaphore_signal(done);
    }] resume];
    dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(25.0 * NSEC_PER_SEC)));

    if (!requestData.length) return nil;
    id json = [NSJSONSerialization JSONObjectWithData:requestData options:0 error:nil];
    return [json isKindOfClass:[NSDictionary class]] ? json : nil;
}

@end
