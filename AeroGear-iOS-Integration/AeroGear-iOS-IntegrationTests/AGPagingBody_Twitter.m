/*
 * JBoss, Home of Professional Open Source
 * Copyright Red Hat, Inc., and individual contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * http://www.apache.org/licenses/LICENSE-2.0
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "AGAbstractBaseTestClass.h"

@interface AGPagingBody_Twitter : AGAbstractBaseTestClass
@end

@implementation AGPagingBody_Twitter {
    id<AGPipe> _tweets;
}

-(void)setUp {
    [super setUp];
    
    // setting up the pipeline for the Twitter pipe
    NSURL* baseURL = [NSURL URLWithString:@"http://search.twitter.com/"];
    AGPipeline* twPipeline = [AGPipeline pipelineWithBaseURL:baseURL];
    
    _tweets = [twPipeline pipe:^(id<AGPipeConfig> config) {
        [config setName:@"search.json"];
        
        [config setNextIdentifier:@"next_page"];
        [config setPreviousIdentifier:@"previous_page"];
        
        [config setMetadataLocation:@"body"];
    }];
}

-(void)tearDown {
    [super tearDown];
}

-(void)testNext {
    __block NSMutableArray *pagedResultSet;
    
    // fetch the first page
    [_tweets readWithParams:@{@"q" : @"aerogear", @"page" : @"1", @"rpp" : @"1"} success:^(id responseObject) {
        pagedResultSet = responseObject;  // page 1
        
        // hold the "tweet id" from the first page, so that
        // we can match with the result when we move
        // to the next page down in the test.
         NSString* tweet_id = [self extractTweetId:responseObject];
        
        // move to the next page
        [pagedResultSet next:^(id responseObject) {
            
            STAssertFalse([tweet_id isEqualToString:[self extractTweetId:responseObject]], @"id's should not match.");
            
            [self setFinishRunLoop:YES];
            
        } failure:^(NSError *error) {
            [self setFinishRunLoop:YES];
            STFail(@"%@", error);
        }];
    } failure:^(NSError *error) {
        [self setFinishRunLoop:YES];
        STFail(@"%@", error);
    }];
    
    // keep the run loop going
    while(![self finishRunLoop]) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
}

-(void)testPreviousFromFirstPage {
    __block NSMutableArray *pagedResultSet;
    
    // fetch the first page
    [_tweets readWithParams:@{@"q" : @"aerogear", @"page" : @"1", @"rpp" : @"1"} success:^(id responseObject) {
        pagedResultSet = responseObject;  // page 1
        
        // move back to an invalid page
        [pagedResultSet previous:^(id responseObject) {
            [self setFinishRunLoop:YES];
            
            STFail(@"should not have called");
            
        } failure:^(NSError *error) {
            [self setFinishRunLoop:YES];
            
            // Note: "failure block" was called here
            // because we were at the first page and we
            // requested to go previous, that is to a non
            // existing page ("previous_page" indentifier
            // was missing from the twitter body response and we
            // got a 403 http error).
            //
            // Note that this is not always the case, cause some
            // remote apis can send back either an empty list or
            // list with results, instead of throwing an error(see GitHub testcase)
            
        }];
    } failure:^(NSError *error) {
        [self setFinishRunLoop:YES];
        STFail(@"%@", error);
    }];
    
    // keep the run loop going
    while(![self finishRunLoop]) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
}

-(void)testMoveNextAndPrevious {
    __block NSMutableArray *pagedResultSet;
    
    // fetch the first page
    [_tweets readWithParams:@{@"q" : @"aerogear", @"page" : @"1", @"rpp" : @"1"} success:^(id responseObject) {
        pagedResultSet = responseObject;  // page 1
        
        // hold the "twitter id" from the first page, so that
        // we can match with the result when we move
        // backwards down in the test.
        NSString* tweet_id = [self extractTweetId:responseObject];
        
        // move to the second page
        [pagedResultSet next:^(id responseObject) {
            
            // move backwards (aka. page 1)
            [pagedResultSet previous:^(id responseObject) {
                
                STAssertEqualObjects(tweet_id, [self extractTweetId:responseObject], @"id's must match.");

                [self setFinishRunLoop:YES];
            } failure:^(NSError *error) {
                [self setFinishRunLoop:YES];
                STFail(@"%@", error);
            }];
        } failure:^(NSError *error) {
            [self setFinishRunLoop:YES];
            STFail(@"%@", error);
        }];
    } failure:^(NSError *error) {
        [self setFinishRunLoop:YES];
        STFail(@"%@", error);
    }];
    
    // keep the run loop going
    while(![self finishRunLoop]) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
}

// helper method to extract the tweet id from the result set
-(NSString*)extractTweetId:(NSArray*) responseObject {
    NSArray* results = [[responseObject objectAtIndex:0] objectForKey:@"results"];

    return [[results objectAtIndex:0] objectForKey:@"id_str"];
}

@end
